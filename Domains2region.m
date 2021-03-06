function region = Domains2region(domains, CC,STATS,region,hemisphereIndices)
%region = Domains2region(domains, CC,STATS,region)
%convert domain assignments from a 3D connected components array to calciumdx region data structure that can be used for rasterplots, and all down stream analysis functions
% need CC, connected components and STATS, the structure returned by regionprops and dummy 'region' file with any regions.coords and .names that you might want to use to label the domains
% James B. Ackman 2013-01-04 22:39:23

if nargin < 5 || isempty(hemisphereIndices), hemisphereIndices = [2 3]; end  %index location of the hemisphere region outlines in the 'region.location' calciumdx struct

region.onsets = {};
region.offsets = {};
region.contours = {};
region.location = [];

sz = CC.ImageSize(1:2);
nROI = numel(hemisphereIndices);
ROImasks = false(sz(1),sz(2),nROI);
se = strel('disk',1);
for j = 1:nROI
	ROImasks(:,:,j) = poly2mask(region.coords{hemisphereIndices(j)}(:,1),region.coords{hemisphereIndices(j)}(:,2),sz(1),sz(2));
	ROImasks(:,:,j) = imdilate(ROImasks(:,:,j),se);
	%figure; imshow(regionMask1);
end

for i = 1:length(domains)
	onsets = [];
	offsets = [];
	%maxampl = [];  %TODO:
	%meanampl = []; %TODO:
		
	OrigIndex = unique(domains(i).OrigDomainIndex);
	
	for j = 1:length(OrigIndex)
		onsets = [onsets ceil(STATS(OrigIndex(j)).BoundingBox(3))];
		offsets = [offsets ceil(STATS(OrigIndex(j)).BoundingBox(3))+(ceil(STATS(OrigIndex(j)).BoundingBox(6))-1)];
	end
	region.onsets{i} = onsets;
	region.offsets{i} = offsets;
	
	BW = false(CC.ImageSize(1:2));
	BW(domains(i).PixelInd) = true;
	[BP2,~] = bwboundaries(BW,'noholes');
	boundary = BP2{1};
	locatmp = [boundary(:,2) boundary(:,1)];
	region.contours{i} = locatmp;
	
	STATS2 = regionprops(BW,'Centroid');
	% centrInd = sub2ind(CC.ImageSize(1:2),round(STATS2(1).Centroid(2)),round(STATS2(1).Centroid(1)));
	centrRowCol = [round(STATS2(1).Centroid(2)) round(STATS2(1).Centroid(1))];

	region.location(i) = 1;
	
	for j=1:nROI
		%regionMask1 = ROImasks(:,:,j);
		% if regionMask1(centrInd) > 0
		if ROImasks(centrRowCol(1),centrRowCol(2),j) > 0
			region.location(i) = hemisphereIndices(j);
		end
	end
end 

region.traces = ones(length(domains),CC.ImageSize(3));  %make dummy traces for now. TODO
