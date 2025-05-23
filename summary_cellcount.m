%% extract number of double AF488 & AF647 for ROIs
cells_path = 'X:\Tom\Master\Registrations cATR\CN-MS\finalSummary_MSdoublecells';
% define the excel sheet with all cell data in it

fluorescence = {'Cy3-AF488 s1','AF488 s1','Cy3 s1',...
                'Cy3-AF488 s2','AF488 s2','Cy3 s2',...
                'Cy3-AF488 s3','AF488 s3','Cy3 s3',...
                'Cy3-AF488 s4','AF488 s4','Cy3 s4',...
                'Cy3-AF488 s5','AF488 s5','Cy3 s5'};
summary_structs = {'PB','CUN','PL','ILA','RR','MEV','STRd','STRv','STR',...
                   'LZ','PAG','PARN','LDT','PVT','PH','PPN','APR','AN','ZI'};

dat = zeros(length(summary_structs), length(fluorescence));
fluorescence_names = matlab.lang.makeValidName(fluorescence, 'ReplacementStyle', 'hex');

cellcount_sum = array2table(dat, 'VariableNames', fluorescence_names);
cellcount_sum.Properties.RowNames = summary_structs;

%% add all data
nr_sheets = 5;
sheet = 0;
for i = 1: nr_sheets
    [num,txt,cells_data] = xlsread(cells_path,i);   % change sheet for other mice
    nr_rows = size(cells_data,1);
    for k = 1:length(summary_structs)
        for rownr = 1:nr_rows
            if strcmp(cells_data{rownr,1}(2:end-1),summary_structs{k}) || strcmp(cells_data{rownr,2}(2:end-1),summary_structs{k})       % remove the '' 
                cellcount_sum{k,1+sheet*3} = cellcount_sum{k,1+sheet*3} + cells_data{rownr,3};
                cellcount_sum{k,2+sheet*3} = cellcount_sum{k,2+sheet*3} + cells_data{rownr,5};
                cellcount_sum{k,3+sheet*3} = cellcount_sum{k,3+sheet*3} + cells_data{rownr,6};
            end
        end
    end
    disp('sheet done')
    sheet = sheet +1;
    disp(sheet)
    
    
    
end