%% script for counting cells in relevant brain regions
% specify a couple of brain region to look for, further, say if the brain
% region is large enough (does not have more than x parents anymore, put it in the list)

%% needed input files
% file with all structures and their hierarchy
struct_path = 'X:\Tom\Master\summary_structs_edit.xlsx';
% excel file with cells per brain region
cells_path = 'X:\Tom\Master\Registrations cATR\CN-HDB-VDB\Summary_double_cells.xlsx';
% define the excel sheet with all cell data in it
[num,txt,cells_data] = xlsread(cells_path,2); % change sheet for other mice

%% import data and initialize output table
% [num,txt,cells_data2] = xlsread(cells_path,2);
% [num,txt,cells_data3] = xlsread(cells_path,3);
% [num,txt,cells_data4] = xlsread(cells_path,4);

opts = detectImportOptions(struct_path);
opts.VariableNamesRange = 1;
opts.DataRange = 2;
structure_file = readtable(struct_path, opts);
smallest_regions = structure_file(:,'abbreviation'); % column with names of brain region

% make all string names like normal strings
for i = 1:length(cells_data)
    if(~isnan(cells_data{i,1}))
        cells_data{i,1} = erase(cells_data{i,1},"'");
    end
end
    
columnNames = {'SummaryStruct','Ch1-Ch2','Ch1-Ch3','Ch2-Ch3','Triple'};
cellcount_summary = array2table(cell(0,numel(columnNames)), 'VariableNames', columnNames);
% also add regions of interest already to the cellcount_sumamry with 0 cells
cellcount_summary = [cellcount_summary;{'root',0,0,0,0}];

% replace all special characters by underscore
for i = 1:height(structure_file)
    str = structure_file{i,4}{1};
    str = regexprep(str, '[/\-]', '_');
    structure_file{i,4} = {str};
end

%% calculations
for ii = 1:length(cells_data)
    brain_area = cells_data{ii,1};      % current brain area
    if istable(brain_area)
        brain_area = brain_area{1,1};
    end
    doubletriple_data = cells_data(ii,3:6);
    brainregion_row = find(strcmp(structure_file.abbreviation,brain_area));     % which row in the structure overview table
    if isempty(brainregion_row) 
        brainregion_row = find(strcmpi(structure_file.abbreviation,brain_area));
    end
    depth = structure_file{brainregion_row,6};                                  % number of parent regions

    if ~isempty(brainregion_row) && any(strcmp(cellcount_summary.SummaryStruct,brain_area))                  % if already present
        idx = find(strcmp(cellcount_summary.SummaryStruct,brain_area));
        cellcount_summary{idx,2} = {cell2mat(cellcount_summary{idx,2}) + cell2mat(doubletriple_data(1))};
        cellcount_summary{idx,3} = {cell2mat(cellcount_summary{idx,3}) + cell2mat(doubletriple_data(2))};
        cellcount_summary{idx,4} = {cell2mat(cellcount_summary{idx,4}) + cell2mat(doubletriple_data(3))};
        cellcount_summary{idx,5} = {cell2mat(cellcount_summary{idx,5}) + cell2mat(doubletriple_data(4))};
        disp('here 1')
    elseif ~isempty(brainregion_row) % brain region is NOT already in the list
        if strcmp(structure_file{brainregion_row,11}{1},'Y')
            cellcount_summary = [cellcount_summary;{brain_area,cell2mat(doubletriple_data(1)),cell2mat(doubletriple_data(2)),cell2mat(doubletriple_data(3)),cell2mat(doubletriple_data(4))}];
        else
            parent_nr = structure_file{brainregion_row,5};
            parent_row = find(structure_file.structureID == parent_nr);         % search for row of parent region
            parent_name = structure_file{parent_row,4};
            count=1;
            while ~strcmp(structure_file{parent_row,11}{1},'Y') && ~any(strcmp(cellcount_summary.SummaryStruct,parent_name))
                parent_nr = structure_file{parent_row,5};
                parent_row = find(structure_file.structureID == parent_nr);         % search for row of parent region
                parent_name = structure_file{parent_row,4};
                count = count+1;
                disp(count)
            end
            if any(strcmp(cellcount_summary.SummaryStruct,parent_name))                  % if already present
                idx = find(strcmp(cellcount_summary.SummaryStruct,structure_file{parent_row,4}{1}));
                cellcount_summary{idx,2} = {cell2mat(cellcount_summary{idx,2}) + cell2mat(doubletriple_data(1))};     % assign all cells to the right column
                cellcount_summary{idx,3} = {cell2mat(cellcount_summary{idx,3}) + cell2mat(doubletriple_data(2))};
                cellcount_summary{idx,4} = {cell2mat(cellcount_summary{idx,4}) + cell2mat(doubletriple_data(3))};
                cellcount_summary{idx,5} = {cell2mat(cellcount_summary{idx,5}) + cell2mat(doubletriple_data(4))};
                disp('now here')
            else
                cellcount_summary = [cellcount_summary;{parent_name,cell2mat(doubletriple_data(1)),cell2mat(doubletriple_data(2)),cell2mat(doubletriple_data(3)),cell2mat(doubletriple_data(4))}];
            end
        end
    end
end
