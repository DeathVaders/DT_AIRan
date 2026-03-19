%% 系统基础参数设置
format long;                                % 设置高精度显示格式
f = 28e9;                                  % 载波频率: 3.5 GHz
c = physconst('LightSpeed');                % 光速 (约 3e8 m/s)
lambda = c/f;                               % 波长
Nc = 64;                               % 子载波总数 (例如 5G NR 资源块对应数量)
B = 5e5 * Nc;                              % 总带宽: 子载波间隔 * 子载波数
Ts = 1/B;                                   % 采样周期 (约 20 ns)
mapfile = "dji.osm";                        % 加载的地图文件名 (OpenStreetMap)
MaxNumReflections = 10;                     % 射线追踪最大反射次数
numMC = 200;
%% 基站 (BS) 参数设置
%BS_loc = [22.5818, 113.9380];               % 基站地理坐标 [纬度, 经度]
BS_loc = [22.582797, 113.935900];               % 基站地理坐标 [纬度, 经度]
%BS_height = 20;                             % 基站天线挂高 (20米)
BS_height = 100;                             % 基站天线挂高 (100米)
BS_Tx = [1, 1];                             % 基站天线阵列配置 [行, 列]
Tx_num = prod(BS_Tx);                       % 总发射天线数 (8*4=32)
Tx_rotation = [0; 0];                       % 天线阵列旋转角 [方位角; 仰角]
Tx_ant_spacing = 0.5;                       % 天线间距 (以波长为单位，通常为 0.5λ)

%% 用户终端 (UE) 参数设置
UE_loc = zeros(2);
UE_height = 2;                            % 用户设备高度 (此处设为 100m，模拟无人机场景)
UE_Rx = [8, 4];                             % 用户接收天线配置 (单天线)
Rx_num = prod(UE_Rx);                       % 总接收天线数
Rx_rotation = [0; 0];                       % 接收天线旋转角
Rx_ant_spacing = 0.5;                       % 接收天线间距

R = 6371e3;                                 % 地球平均半径 (6371 km)

% 将米转换成经纬度跨度的比例因子
lat2meter = 360 / (2 * pi * R);                   % 1米对应的纬度差
lont2meter = 360 / (2 * pi * R * cosd(BS_loc(1))); % 1米对应的经度差 (随纬度变化)

disp("参数初始化完成，BS、UE 坐标已生成。");