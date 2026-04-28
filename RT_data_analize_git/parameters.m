%% 系统基础参数设置
format long;
f = 7e9;
c = physconst('LightSpeed');
lambda = c / f;
Nc = 528 * 12;
B = 30e3 * Nc;
Ts = 1 / B;
mapfile = "3gpp_urban_grid_true.osm";
MaxNumReflections = 10;
max_paths = 12;               % 最大路径数：超出忽略，不足按实际数使用
MaxRelativePathLoss = 100;
MaxNumDiffractions = 0;

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
BS_height = 5;                                 % 基站天线挂高 (5米)
% BS_height = 25;                              % 基站天线挂高 (25米)
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
% UE_directions_by_BS = {
%     ["EW"; "NS"; "EW"; "NS"]
%     ["EW"; "NS"; "NS"; "EW"; "EW"]
%     ["NS"; "EW"; "NS"]
% };                                              % LOS每个 UE 对应街道方向标签，只允许 "EW" 或 "NS"
UE_directions_by_BS = {
    ["NS"; "EW"; "NS"; "EW"]
    ["NS"; "EW"; "NS"]
    ["NS"]
    ["EW"; "NS"]
};                                              % NLOS每个 UE 对应街道方向标签，只允许 "EW" 或 "NS"

BS_loc = BS_locs(1, :);                         % 当前仿真默认使用的 BS，由主脚本覆盖
UE_loc = zeros(2);
UE_direction = "EW";
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

% 将米转换成经纬度跨度的比例因子
lat2meter = 360 / (2 * pi * R);
lont2meter = 360 / (2 * pi * R * cosd(BS_locs(1, 1)));

validate_scenario_config(BS_locs, UE_points_by_BS, UE_directions_by_BS);
disp("参数初始化完成，BS/UE 场景配置已加载。");

function validate_scenario_config(BS_locs, UE_points_by_BS, UE_directions_by_BS)
if ~iscell(UE_points_by_BS)
    error("UE_points_by_BS 必须是 cell 数组，每个 BS 对应一个 cell。");
end

if ~iscell(UE_directions_by_BS)
    error("UE_directions_by_BS 必须是 cell 数组，每个 BS 对应一个 cell。");
end

if size(BS_locs, 2) ~= 2
    error("BS_locs 必须是 N×2 的 [lat, lon] 矩阵。");
end

if numel(UE_points_by_BS) ~= size(BS_locs, 1)
    error("UE_points_by_BS 的 cell 数量必须与 BS_locs 的行数一致。");
end

if numel(UE_directions_by_BS) ~= size(BS_locs, 1)
    error("UE_directions_by_BS 的 cell 数量必须与 BS_locs 的行数一致。");
end

for bs_idx = 1:numel(UE_points_by_BS)
    ue_points = UE_points_by_BS{bs_idx};
    ue_dirs = string(UE_directions_by_BS{bs_idx});

    if isempty(ue_points)
        error("BS%d 没有配置任何 UE 点位。", bs_idx);
    end
    if size(ue_points, 2) ~= 2
        error("UE_points_by_BS{%d} 必须是 M×2 的 [lat, lon] 矩阵。", bs_idx);
    end
    if numel(ue_dirs) ~= size(ue_points, 1)
        error("BS%d 的 UE 方向标签数量必须与 UE 点位数量一致。", bs_idx);
    end
    if any(~ismember(ue_dirs, ["EW", "NS"]))
        error("BS%d 的 UE 方向标签只允许取值 EW or BS", bs_idx);
    end
end
end
