%% Simulation parameters
format long;
f = 7e9;
c = physconst('LightSpeed');
lambda = c / f; 
Nc = 528 * 12;
B = 30e3 * Nc;
Ts = 1 / B; 
mapfile = "3gpp_urban_grid_true.osm";
MaxNumReflections = 10;
max_paths = 12; 
MaxRelativePathLoss = 100;
MaxNumDiffractions = 0;

%% Base station configuration
%% 基站 (BS) 参数设置
% BS_locs = [
%     39.902651,116.405189
%     39.906354,116.404940
%     39.902674,116.404909
% ];                                              % LOS多个基站地理坐标 [纬度, 经度]
BS_locs = [
    39.906619,116.401849
    39.902651,116.405189
    39.902680,116.404878
    39.902674,116.404909
];                                              % NLOS多个基站地理坐标 [纬度, 经度]
BS_height = 5;
BS_Tx = [8, 8];
Tx_num = prod(BS_Tx);
Tx_rotation = [0; 0];
Tx_ant_spacing = 0.5; 

%% 用户终端 (UE) 参数设置
% UE_points_by_BS = {
%     [
%         39.902469,116.403603%EW
% 	    39.901776,116.404950%NS
% 	    39.902470,116.407115%EW
% 	    39.903383,116.404953%NS
%     ]
%     [
%         39.906535,116.407254%EW
% 	    39.907365,116.405173%NS
% 	    39.904735,116.405173%NS
% 	    39.906535,116.403005%EW
% 	    39.906534,116.403433%EW
%     ]
%     [
%         39.901462,116.405172%NS
% 	    39.902469,116.406769%EW
% 	    39.903727,116.405171%NS
%     ]
% };                                              % LOS每个 cell 对应一个 BS 下的所有 UE 点位
UE_points_by_BS = {
    [
        39.907557,116.402229%NS
	    39.906362,116.400491%EW
	    39.905429,116.402021%NS
	    39.906532,116.404234%EW
    ]
    [
        39.901712,116.405167%NS
	    39.902632,116.407125%EW
	    39.903667,116.405174%NS
    ]
    [
        39.902383,116.402022%NS
    ]
    [
        39.902640,116.402620%EW
	    39.903607,116.404957%NS
    ]
};                                              % NLOS每个 cell 对应一个 BS 下的所有 UE 点位

UE_loc = zeros(2);
UE_height = 1.5;
UE_Rx = [2, 2];
Rx_num = prod(UE_Rx); 
Rx_rotation = [0; 0];
Rx_ant_spacing = 0.5;
Nx = UE_Rx(1);
Ny = UE_Rx(2);
sc_idx = (0:Nc - 1)';
f_k = sc_idx * (B / Nc);

PDP_delay_grid_ns = 0:0.1:1000;
PDP_delay_grid_s = PDP_delay_grid_ns * 1e-9;
AZ_angle_grid_deg = -180:1:180;
EL_angle_grid_deg = 0:1:90;

R = 6371e3;
lat2meter = 360 / (2 * pi * R); 
lont2meter = 360 / (2 * pi * R * cosd(BS_locs(1, 1))); 

validate_scenario_config(BS_locs, UE_points_by_BS);
disp("Loaded BS/UE scenario configuration.");

function validate_scenario_config(BS_locs, UE_points_by_BS)
if ~iscell(UE_points_by_BS)
    error("UE_points_by_BS must be a cell array, one cell per BS.");
end

if size(BS_locs, 2) ~= 2
    error("BS_locs must be an N-by-2 matrix of [lat, lon].");
end

if numel(UE_points_by_BS) ~= size(BS_locs, 1)
    error("The number of UE point sets must match the number of BS locations.");
end

for bs_idx = 1:numel(UE_points_by_BS)
    ue_points = UE_points_by_BS{bs_idx};
    if isempty(ue_points)
        error("BS%d has no UE points configured.", bs_idx);
    end
    if size(ue_points, 2) ~= 2
        error("UE_points_by_BS{%d} must be an M-by-2 matrix of [lat, lon].", bs_idx);
    end
end
end
