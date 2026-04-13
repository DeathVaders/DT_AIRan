%% 系统基础参数设置
format long;
f = 7e9;
c = physconst('LightSpeed');
lambda = c / f;
Nc = 528*12;
B = 30e3*Nc;
Ts = 1 / B;
mapfile = "3gpp_urban_grid_true.osm";
MaxNumReflections = 10;
max_paths = 12;               % 最大路径数：超出忽略，不足按实际数使用
MaxRelativePathLoss = 100;
MaxNumDiffractions = 1;
%% 基站 (BS) 参数设置
BS_loc = [39.906455, 116.402087];              % 基站地理坐标 [纬度, 经度]
BS_height = 5;                             % 基站天线挂高 (20米)
% BS_height = 100;                             % 基站天线挂高 (100米)
BS_Tx = [8, 8];
Tx_num = prod(BS_Tx);
Tx_rotation = [0; 0];
Tx_ant_spacing = 0.5;

%% 用户终端 (UE) 参数设置
UE_loc = zeros(2);
UE_height = 1.5;
UE_Rx = [2, 2];
Rx_num = prod(UE_Rx);
Rx_rotation = [0; 0];
Rx_ant_spacing = 0.5;
Nx = UE_Rx(1);
Ny = UE_Rx(2);
sc_idx = (0:Nc-1)';
f_k = sc_idx * (B / Nc);

R = 6371e3;

% 将米转换成经纬度跨度的比例因子
lat2meter = 360 / (2 * pi * R);
lont2meter = 360 / (2 * pi * R * cosd(BS_loc(1)));

disp("参数初始化完成，BS、UE 坐标已生成。");
