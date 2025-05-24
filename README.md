# Master-thesis
Scripts used for the data analysis-pipeline of my master thesis

How to use the scripts and in which order to use them:
First, register brain slices in ABBA and export the atlas annotations back onto the project.
1. In QuPath, run CellDetection-2Channels.groovy OR CellDetection-3Channels.groovy for the whole project. This depends on whether the dataset has 2 or 3 fluorophores on which double cell counting can be performed.__
   **SPECIFY**: In these files, specify the names of the fluorophores as they are called in QuPath. This can be checked under view -->       adjust brighness and contrast. Also specify the optimal detection parameters and the output path for the info about detected cells.
2. In MATLAB, run cellcounting.m to calculate the number of single, double and triple labeled cells per brain region if applicable. This returns a table called doubleCounts with all smallest brain regions (Column 1) and their parent structures (Column 2) with the number of double labeled cells in the next columns. It also returns doubleCells, with all double labeled cells and their detection coordinates, distance between the centers and slice in which it was detected in the columns next to it. Lastly, areaList gives the brain regions like in doubleCounts, but with all single labeled cells in the columns next to it: Channel 1, Channel 2, (Channel 3).  
   **SPECIFY**: Path to the folder where the QuPath output csv files are located. Names of the fluorophores in the order in which they are detected. That is, in the order that they were specified in the Groovy detection script. Lastly, the threshold that the centers of detection need to be within to be counted as double cells.
3. To go from the detected cells per brain region to an overviews of detected cells per summary structure, run cells_to_summary_structs.m  
   **SPECIFY**: The csv file where the double cells are located. This file needs to be of the format: summary structures that 
