function batchFetchRegionSize(filelist,region, datafilename, useStimuli, stimuliIndices)
%batchFetchRegionSize - A wrapper and output generator for getting information on rois widths and heights
%Examples:
% >> batchFetchRegionSize(filelist);
% >> batchFetchRegionSize({filename},region);
% >> batchFetchRegionSize({filename},region,'dRegionSize.txt');
%
%**USE**
%Must provide one input:
%
%(1) table with desired filenames (space delimited txt file, with full filenames in first column)
%files.txt should have matlab filenames in first column.
%can have an extra columns with descriptor/factor information for the file. This will be the rowinfo that is attached to each measure observation in the following script.
%filelist = readtext('files.txt',' '); %grab readtext.m file script from matlab central
%or
%(2) a single filename (filename of your region .mat file) as a cell array, i.e.  {filename}
%
%Options:
%filelist={filename}; % cell array of strings, can pass just a single filename and a single already loaded region structure, if only getting values for a single file.
%region - datastructure, if you just want to do a single file loaded into workspace
%datafilename - string, append data to prexisting table with filename 'datafilename'
%useStimuli - string, 'true' | 'false'
%stimuliIndices - integer vector of stimulus indices or a cell array of strings of stimulus descriptions for selecting stimuli in your region.stimuli data structure
%
%Output:
%This function will automatically write to a space-delimited txt file.
%And these outputs will be appended if the file already exists.
%
% See also wholeBrain_getActiveFractionPeriods.m, wholeBrain_activeFraction.m, batchFetchStimResponseProps, batchFetchCalciumEventProps.m, batchFetchDomainProps.m
%
%James B. Ackman, 2014-06-19 14:07:16

%-----------------------------------------------------------------------------------------
%- Set up options and default parameters
%-----------------------------------------------------------------------------------------



if nargin< 5 || isempty(stimuliIndices); stimuliIndices = []; end 
if nargin< 4 || isempty(useStimuli); useStimuli = 'false'; end
if nargin< 3 || isempty(datafilename), 
	datafilename = 'dRegionSize.txt';
	matlabUserPath = userpath;  
	matlabUserPath = matlabUserPath(1:end-1);  
	datafilename = fullfile(matlabUserPath,datafilename);
else
	[pathstr, name, ext] = fileparts(datafilename);   %test whether a fullfile path was specified	
	if isempty(pathstr)  %if one was not specified, save the output datafilename into the users matlab home startup directory
		matlabUserPath = userpath;  
		matlabUserPath = matlabUserPath(1:end-1);  
		datafilename = fullfile(matlabUserPath,datafilename);		
	end
end
if nargin< 2 || isempty(region); region = []; end

%---**functionHandles.workers and functionHandles.main must be valid functions in this program or in matlabpath to provide an array of function_handles
functionHandles.workers = {@filename @matlab_filename @region_name2 @roi_width_px @roi_height_px};
functionHandles.main = @wholeBrain_getDomainStats;
%tableHeaders = {'filename' 'matlab.filename' 'region.name' 'roi.number' 'nrois' 'roi.height.px' 'roi.width.px' 'xloca.px' 'yloca.px' 'xloca.norm' 'yloca.norm' 'freq.hz' 'intvls.s' 'onsets.s' 'durs.s' 'ampl.df'};
%filename %roi no. %region.name %roi size %normalized xloca %normalized yloca %region.stimuli{numStim}.description %normalized responseFreq %absolutefiringFreq(dFreq) %meanLatency %meanAmpl %meanDur

tableHeaders = cellfun(@func2str, functionHandles.workers, 'UniformOutput', false);
%---Generic opening function---------------------
setupHeaders = exist(datafilename,'file');
if setupHeaders < 1
	%write headers to file----
	fid = fopen(datafilename,'a');
	appendCellArray2file(datafilename,tableHeaders,fid)
else
	fid = fopen(datafilename,'a');
end

%---Generic main function loop-------------------
%Provide valid function handle
mainfcnLoop(filelist, region, datafilename, functionHandles, [], fid, useStimuli, stimuliIndices)
fclose(fid);


function mainfcnLoop(filelist, region, datafilename, functionHandles, datasetSelector, fid, useStimuli, stimuliIndices)
%start loop through files-----------------------------------------------------------------

if nargin < 5 || isempty(datasetSelector), datasetSelector=[]; end
if nargin < 7 || isempty(useStimuli), useStimuli=[]; end
if nargin < 8 || isempty(stimuliIndices), stimuliIndices=[]; end

if nargin< 2 || isempty(region); 
    region = []; loadfile = 1; 
else
    loadfile = 0;
end

fnms = filelist(:,1);

if size(filelist,1) > 1 && size(filelist,2) > 1
	fnms2 = filelist(:,2);
end

for j=1:numel(fnms)
    if loadfile > 0
        matfile=load(fnms{j});
        region=matfile.region;
    end
    
    if ~isfield(region,'filename')    
		if size(filelist,2) > 1 && ~isfield(region,'filename')
			[pathstr, name, ext] = fileparts(fnms2{j});
			region.filename = [name ext];  %2012-02-07 jba
		else
			region.filename = ['.tif'];
		end
    end
	[pathstr, name, ext] = fileparts(fnms{j});
	region.matfilename = [name ext];  %2012-02-07 jba    
	
%	rowinfo = [name1 name2];  %cat cell array of strings
%	rowinfo = filelist(j,:);
    sprintf(fnms{j})    

    disp('--------------------------------------------------------------------')
	%myEventProps(region,rowinfo);
	functionHandles.main(region, functionHandles.workers, datafilename, datasetSelector, fid, useStimuli, stimuliIndices)
	if ismac | ispc
		h = waitbar(j/numel(fnms));
	else
		disp([num2str(j) '/' num2str(numel(fnms))])		
    end
end
%data=results;
if ismac | ispc
	close(h)
end










%-----------------------------------------------------------------------------------------
%dataFunctionHandle
function output = wholeBrain_getDomainStats(region, functionHandles, datafilename, datasetSelector, fid, useStimuli, stimuliIndices)
%script to fetch the active and non-active pixel fraction period durations
%for all data and all locations
%2013-04-09 11:35:04 James B. Ackman
%Want this script to be flexible to fetch data for any number of location Markers as well as duration distributions for both non-active and active periods.  
%Should get an extra location signal too-- for combined locations/hemisphere periods.
%2013-04-11 18:00:23  Added under the batchFetchLocation generalized wrapper table functions

varin.datafilename=datafilename;
varin.region=region;

if strcmp(useStimuli,'true') & isempty(stimuliIndices) & isfield(region,'stimuli'); 
	stimuliIndices=1:numel(region.stimuli);
elseif strcmp(useStimuli,'true') & iscellstr(stimuliIndices) & isfield(region,'stimuli')  %if the input is a cellarray of strings
		ind = [];
		for i = 1:length(region.stimuli)
			for k = 1:length(stimuliIndices)
				if strcmp(region.stimuli{i}.description,stimuliIndices{k})
					ind = [ind i];
				end
			end
		end
		stimuliIndices = ind; %assign indices 
elseif strcmp(useStimuli,'true') & isnumeric(stimuliIndices) & isfield(region,'stimuli')
	return
elseif ~isfield(region,'stimuli') || strcmp(useStimuli,'false')
	stimuliIndices = [];
else
	error('Bad input to useStimuli, stimuliIndices, or region.stimuli missing')
end

for idx = 1:length(region.name)
	varin.idx = idx;
	varin.name = region.name{idx};
	printStats(functionHandles, varin, fid)
end	


function out = filename(varin) 
%movie .tif filename descriptor string
out = varin.region.filename;

function out = matlab_filename(varin)
%analysed .mat file descriptor string
out = varin.region.matfilename;

function out = region_name2(varin) 
%movie .tif filename descriptor string
out = varin.name;

function out = roi_width_px(varin)
%location name descriptor string
dim = max(varin.region.coords{varin.idx}) - min(varin.region.coords{varin.idx}) + 1;
out = dim(1);

function out = roi_height_px(varin)
%location name descriptor string
dim = max(varin.region.coords{varin.idx}) - min(varin.region.coords{varin.idx}) + 1;
out = dim(2);
