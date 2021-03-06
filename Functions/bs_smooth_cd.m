function change_map = bs_smooth_cd(dataset, n_samples, Ksmooth, stop)

% Blue noise and Nystrom extension for graph based change detection
% Paper presented at IGARSS 2021
%
%
% FORMAT change_map = bs_smooth_cd(dataset, n_samples, Ksmooth, stop)
%
% Inputs:
% dataset     - Contains an availabla dataset in string format or
%               a cell array with size 2 with before and after images
% n_samples   - Number of sample nodes (pixels).
% Ksmooth     - Parameter for smoothnes prior (edges per node).
% stop        - Controls the number of regions generated by graph cut
%               algorithm
%
% Output:
% Change_map  - Binary image of the change zone detected
%__________________________________________________________________________
% Copyright (C) 2021
% David Alejandro Jimenez Sierra

%--------------------Available datasets-----------------------
%   Wenchuan_dataset
%   sardania_dataset
%   alaska_dataset
%   Madeirinha_dataset
%   omodeo_dataset
%   SF_dataset
%   dique_dataset
%   katios_dataset
%   canada_dataset
%   contest_dataset
%   california_flood
%   Bastrop_dataset
%   gloucester_dataset
%   toulouse_dataset
%-------------------------------------------------------------

% These are the stop and Ksmooth parameters used in the paper for the each dataset enumerate before:
%
% stop = [0.001,0.00085,0.004,0.0005122,0.01,0.0005,0.0000095,0.0004,0.0002,...
%        0.000045,0.0002,0.0025,0.000015,0.0000065];
%
% Ksmooth = [15, 177, 79, 166, 796, 276, 114, 423, 415, 749, 206, 733, 89, 68];
%
% For instance for Wenchuan_dataset the stop is 0.001, for sardania_dataset
% stop is 0.0085 and so on.

%% Validation of inputs

if isa(dataset,'cell')
    before = dataset{1};
    after = dataset{2};
elseif isa(dataset,'string')
    load(dataset)
else
    msgbox('The dataset must be a cell by 1x2 with before and after images or a string with the name of an available dataset',...
        'Error','Error');
    return;
end

if isa(n_samples,'double')
    if floor(n_samples) ~= n_samples
        
        msgbox('The number of samples n must be an integer',...
            'Error','Error');
        return;
        
    end
end

if isa(Ksmooth,'double')
    if floor(Ksmooth) ~= Ksmooth
        
        msgbox('The parameter Ksmooth must be an integer',...
            'Error','Error');
        return;
        
    end
end

if nargin < 4
    
    msgbox('There are missing parameters. The algorithm needs the four parameters to run.',...
        'Error','Error');
    return;
    
end

warning off

%% Normalization of the data

after = double(after);
before = double(before);

maxA = max(max(after));
after = (after./maxA);

maxA = max(max(before));
before = (before./maxA);

Xl = cell(2,1);
Xl{1} = after;
Xl{2} = before;

[rows,cols,~] = size(before);

%% Smoothness prior
[centroids, region1, region2] = generate_regions(before, after, stop, Xl);

ro = sqrt((region2(:) - region1(:)).^2); %Magnitude of the difference image

ZAA = gsp_distanz(ro');

disp('Genration of regions done...');


[thetaAA, ~, ~] = gsp_compute_graph_learning_theta(ZAA,Ksmooth);
[WsmoothAA] = gsp_learn_graph_log_degrees(ZAA*thetaAA,1,1);
WsmoothAA(WsmoothAA<1e-4) = 0;


Am = WsmoothAA;
disp('Smoothness prior done')

clearvars -except Am centroids Xl n_dataset stop datasets samples rows cols ...
    ksmooth gt sampling_pattern kappas ZAA b kmin k_cont biaoji n_samples

%% Blue-Noise
geodesic_distances = distances(graph(Am));

idx = find(geodesic_distances == inf);
geodesic_distances(idx) = nan;
geodesic_distances(idx) = max(max(geodesic_distances));
disp('Geodesic distances Done')



%% Blue noise sampling pattern generation.
amount_nodes = n_samples; % Amount of nodes
sampling_pattern{1} = blue_noise_sampling_pattern(gsp_graph(Am),geodesic_distances,amount_nodes,0,1000);
disp('Blue-Noise sampling done...')


%% Nystrom
idx = find(sampling_pattern{1});
locations = sub2ind([rows  cols],centroids(idx,1),centroids(idx,2));


n = length(locations);

% Check for repeat values
[~ , indx] = unique(locations);

if length(indx) ~= n
    duplicate = setdiff(1:n, indx);
    locations(duplicate) = locations(duplicate) + 1;
else
    clear indx
end


%Plot the selected samples

figure
imshow(Xl{1},[]);
hold on
plot(centroids(idx,2),centroids(idx,1),'rx', 'LineWidth', 2)
drawnow

clearvars -except locations centroids Xl n_dataset stop datasets samples n_sampl ...
    rows cols ksmooth gt sampling_pattern kappas ZAA b kmin k_cont biaoji

%% Apply graph fusion and detect the change map

change_map = gbf_cd(Xl, locations);

