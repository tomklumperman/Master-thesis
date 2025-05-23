%% clear workspace
clear; clc;

%% General settings 

% specify folder that contains the csv files with detected cells 
path_root = 'X:\Tom\Master\Registrations cre staining\cell-counting_output-M24-03857-04';
keep = {'doubleCounts','areaList', 'doubleCells', 'csvFile','path_root','files','slice_count', 'Channel1', 'Channel2', 'Channel3','distance_thres','keep'};
% Channels below should be in the order of the detection, so if AF488 is first detected, it should be Channel1
Channel1 = 'Cy3'; % In the rest of the script, references to Channel1 might be called "AF488 cells", etc..
Channel2 = 'Cy5';   % In the rest of the script, references to Channel1 might be called "Cy cells", etc..
Channel3= 'X';       % enter 'X' if no 3rd channel

distance_thres = 8; % micrometers that cell middle points of different fluorescence need to be within for double classification

% areaList first column is the smallest brain region, second column is the parent region!
%% obtain csv files and run calculations
% csvFile = 'F:\Tom\QuPath-output\M24-002180-01-LoopTest\double-cell-M24-002180-01';
if ~isfolder(path_root)
    errorMessage = sprintf('Error: This folder does not exist');
    uiwait(warndlg(errorMessage));
    path_root = uigetdir();     % ask to specify new folder
end

files = dir(fullfile(path_root,'*.csv'));   % get all files in the folder

% make a loop over all csv files in one directory here
% overwrite most of the data, but some should be appended and added up to each other
% these are: areaList, doubleCells. Here, the data about cells through the whole brain are stored

for csvFile = files'
    
    % clear all variables, except the ones that are needed for full brain analysis
    clearvars('-except', keep{:});
    filename = csvFile.name;
    csvFile = strcat(path_root,'\',filename);       % take the name of the whole path with the csv file
    slice_number = csvFile(end-5:end-4);            % easy to show and save slice number with every cell and show in command window

    % Import CSV data, with headers for each column
    opts = detectImportOptions(csvFile);
    opts.VariableNamesLine = 1;
    opts.DataLines = 2;
    data = readtable(csvFile, opts);

    % make all names in data valid, so no '-', but '_'
    data{:,2:3} = matlab.lang.makeValidName(data{:,2:3});

    % Extract relevant columns
    brainAreas = data{:,2:3};
    fluorescence = data.Fluorescence;
    x = data.X;
    y = data.Y;

    % Get unique brain areas with their parent region
    [~,uniqueIdx] = unique(brainAreas(:,1),'stable');
    uniqueAreas = brainAreas(uniqueIdx,:);

    % initialize cell for all Cy3 and all AF488 counted cells seperately with x and y coordinate for later
    CH1cells = {};
    CH2cells = {};
    CH3cells = {};        % only needed if third channel specified

    % create a variable with all unique brain areas to check the row where to increase the cell count
    % do this only if not initialized !! otherwise add areas to the list
    if exist('areaList','var') == 1
        for ii = 1:length(uniqueAreas)
            if ~ismember(uniqueAreas{ii,1},string(areaList(:,1)))             % check if brain area was already in a previous slide, or if it should be added
                areaList = vertcat(areaList,{uniqueAreas{ii,1},uniqueAreas{ii,2},0,0,0});       % add new brain area to the list
                doubleCounts = vertcat(doubleCounts,{uniqueAreas{ii,1},uniqueAreas{ii,2},0,0,0,0});   % also add brain area to list for double and triple labeled cells
            end
        end
    else
        areaList = uniqueAreas;                                             % first slice, initialize variable
        areaList(:,3:5) = num2cell(zeros(length(areaList),3));              % add 0 to all counts in advance, to prevent problems
        doubleCounts = uniqueAreas;                                         % do the same for an array that will store double and triple labeled cells per area
        doubleCounts(:,3:6) = num2cell(zeros(length(doubleCounts),4));      % add 0 to all counts in advance, to prevent problems
    end
    areaStruct = struct();
    % make a table to store all cell info per brain region
    for k = 1:length(areaList)
        if ~isfield(areaStruct,areaList{k,1})       % check if there is already a field for this brain area
            areaStruct.(areaList{k,1}) = {};        % otherwise make an empty field to add cells
        end
    end

    %% Loop through all detected cells, and bin info per brain area
    % when cell is in a specific parent area, find the row of this area in uniqueAreas -->
    % put the number of detected cells next to it. CH1 in column 3, CH2 in column 4, CH3 in column 5
    % Double labeled and triple labeled cells go into a different variable.
    for i = 1:height(data)
        brainregion = data{i,2};  % extract brain region from every row in data
        fluorescence = data{i,4}; % 
        brainregionRow = find(ismember(string({areaList{:,1}}),brainregion{1})); % get the row number of the brain region where this cell was detected
        if strcmp(Channel1,fluorescence)      % add cell to the second column if fluorescence of the cell is A488
            areaList{brainregionRow,3}= areaList{brainregionRow,3} + 1;     % add one in the cellcount of AF488 (SECOND column for AF488)
            CH1cells = [CH1cells; {i,data{i,5},data{i,6}}];                 % add cell coordinates
        elseif strcmp(Channel2,fluorescence)   % go to the third column if fluorescence of the cell is Cy3
            areaList{brainregionRow,4}= areaList{brainregionRow,4} + 1;     % add one in the cellcount (THIRD column for Cy3)
            CH2cells = [CH2cells; {i,data{i,5},data{i,6}}];                 % add cell coordinates
        elseif strcmp(Channel3,fluorescence)   % go to the fourth column if fluorescence of the cell is the one of Channel3
            areaList{brainregionRow,5}= areaList{brainregionRow,5} + 1;     % add one in the cellcount (Fourth column for channel 3)
            CH3cells = [CH3cells; {i,data{i,5},data{i,6}}];                 % add cell coordinates
        end

        % add fluorescence and coordinates to a structure per brain area, for double cell calculation
        key = data{i,3};                                                    % get the brain region to append cells to the right field
        key = key{1};
        if isfield(areaStruct,key)
            coord = data{i,5:6};                                            % x and y coordinates
            areaStruct.(key)(end+1,:) = {data{i,4}{1}, coord};              % structure with cells and their fluorescence + coordinates per brain area
        end
    end
    disp(['cell quantification before double cell counting done for slice number ', slice_number])
    % above this the code works for 2 channels, 3 channels not tested yet
    
    %% double labeled cells calculation
    fn = fieldnames(areaStruct);        % take all fieldnames to loop over. 'areastruct' is restored every loop, so all cells per brain slice are considered only once.
    columnNames = {'SmallestBrainRegion','ParentRegion',['Xcoord ' Channel1],['Ycoord ' Channel1],['Xcoord ' Channel2],['Ycoord ' Channel2],['Xcoord ' Channel3],['Ycoord ' Channel3],'distance','SliceNumber'};   % info on double labeled cells

    if exist('doubleCells','var') == 0
        doubleCells = array2table(cell(0,numel(columnNames)), 'VariableNames', columnNames);            % initialize table on first loop     
    end
    for j=1:numel(fn)                   % loop over number of fields, so look at the cells per brainregion
        count=1;
        brainregionRow = find(ismember(string({areaList{:,1}}),fn{j}));                                 % get the row of the brainregion where to store the double labeled cells
        if ~isempty(areaStruct.(fn{j}))                                                                 % only makes sense when there are cells detected in the brain structure
            CH2_cells = find(contains(areaStruct.(fn{j})(:,1),Channel2));                               % store indices where channel 2 cells are, to compare the channel 1 cells with
            CH3_cells = find(contains(areaStruct.(fn{j})(:,1),Channel3));                               % indices where channel 3 cells are, to compare with the other channels
            while strcmp(areaStruct.(fn{j}){count,1},Channel1) && count < size(areaStruct.(fn{j}),1)    % !! This probably onlyl works when AF488 cells are on top of the list (first detected). Loop only over AF488 cells in each structure 
                for z =1:length(CH2_cells)                                                              % loop over Cy3 cells to compare with AF488 cells
                    distance = pdist2(areaStruct.(fn{j}){count,2},areaStruct.(fn{j}){CH2_cells(z),2});  % calculate distance between cells from the first channel (count) and the second channel (CH2_cells(z))
                    if distance < distance_thres                                                                     % distance threshold, change this according to data. A reasonable number could be < 10 (micrometers)
                        doubleCounts{brainregionRow, 3} = doubleCounts{brainregionRow, 3} + 1;          % +1 for double CH1&2 and save info on the double labeled cells below
                        disp([num2str(distance),' micrometer between ',Channel1, ' and ',Channel2, ' in ', areaList{brainregionRow, 1}])        % show the cells that are within this distance
                        % add all info of double labeled cells to a table. The info is the two overlapping detections with their coordinates
                        doubleCells = [doubleCells;{areaList{brainregionRow, 1},areaList{brainregionRow, 2},areaStruct.(fn{j}){count,2}(1),areaStruct.(fn{j}){count,2}(2),areaStruct.(fn{j}){CH2_cells(z),2}(1),areaStruct.(fn{j}){CH2_cells(z),2}(1)},0,0,distance,slice_number];
                    end
                end
                if ~strcmp('X',Channel3)
                    for zz =1:length(CH3_cells)                                                             % loop over channel 3 cells to compare with channel 1 cells
                        distance = pdist2(areaStruct.(fn{j}){count,2},areaStruct.(fn{j}){CH3_cells(zz),2}); % calculate distance between them, count = number of channel 1 cell
                        if distance < distance_thres                                                                     % distance threshold, change this according to data. A reasonable number could be < 10 (micrometers)
                            doubleCounts{brainregionRow, 4} = doubleCounts{brainregionRow, 4} + 1;                  % +1 for double CH1&3 and save info on the double labeled cells below
                            disp([num2str(distance),' micrometer between ',Channel1, 'and ',Channel3, 'in ', areaList{brainregionRow, 1}])        % show the cells that are within this distance
                            % add all info of double labeled cells to a table
                            doubleCells = [doubleCells;{areaList{brainregionRow, 1},areaList{brainregionRow, 2},areaStruct.(fn{j}){count,2}(1),areaStruct.(fn{j}){count,2}(2),0,0,areaStruct.(fn{j}){CH3_cells(zz),2}(1),areaStruct.(fn{j}){CH3_cells(zz),2}(1)},distance,slice_number];
                        end
                    end
                end
                count = count + 1;
            end
            if ~strcmp('X',Channel3)
                for jj = 1:length(CH3_cells)                  % loop over all entries of 3rd channel
                    % extract coordinates of the cell
                    for hh = 1:length(CH2_cells)              % loop over all channel 2 cells, to compare with CH3 cell
                        distance23 = pdist2(areaStruct.(fn{j}){CH3_cells(jj),2},areaStruct.(fn{j}){CH2_cells(hh),2});
                        if  distance23 < distance_thres  % calculate distance between cells from the first channel (count) and the second channel (CH2_cells(z))
                            doubleCounts{brainregionRow, 5} = doubleCounts{brainregionRow, 5} + 1;          % +1 for double CH1&2 and save info on the double labeled cells below
                            disp([num2str(distance23),' micrometer between ',Channel2, ' and ',Channel3, ' in ', areaList{brainregionRow, 1}])        % show the cells that are within this distance
                            % add all info of double labeled cells to a table. The info is the two overlapping detections with their coordinates
                            doubleCells = [doubleCells;{areaList{brainregionRow, 1},areaList{brainregionRow, 2},0,0,areaStruct.(fn{j}){hh,2}(1),areaStruct.(fn{j}){hh,2}(2),areaStruct.(fn{j}){jj,2}(1),areaStruct.(fn{j}){jj,2}(2)},distance23,slice_number];
                            for pp = 1:height(doubleCells)
                                if cell2mat(doubleCells{pp,3})~=0 && cell2mat(doubleCells{pp,5})~=0 && cell2mat(doubleCells{pp,7})==0 &&  str2double(cell2mat(doubleCells{pp,9})) == str2double(slice_number)     % criteria to check for triple labeled cell
                                    distance1 = pdist2(cell2mat(doubleCells{pp,3:4}),areaStruct.(fn{j}){jj,2});             % calculate distance between cell of channel 1 and channel 3
                                    distance2 = pdist2(cell2mat(doubleCells{pp,5:6}),areaStruct.(fn{j}){jj,2});             % calculate distance between cell of channel 2 and channel 3
                                    if or(distance1 < distance_thres,distance2 < distance_thres)                            % one of the distances must be within the threshold
                                        doubleCells{pp,7:8} = {areaStruct.(fn{j}){jj,2}(1),areaStruct.(fn{j}){jj,2}(2)};    % add 3rd channel cell coordinates to the row
                                        doubleCounts{brainregionRow, 6} = doubleCounts{brainregionRow, 6} + 1;              % +1 for triple cells in this brain region
                                        disp(['Triple labeled cell!! in ', areaList{brainregionRow, 1}])
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    disp(filename)
    disp(slice_number)
end
doubleCounts = sortrows(doubleCounts,1);        % sort rows in the cell to get alphabetical order of brain regions
areaList = sortrows(areaList,1);                % sort rows in the cell to get alphabetical order of brain regions