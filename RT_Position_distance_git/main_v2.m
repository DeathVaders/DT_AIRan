%% 初始化与环境清理
clc;        % 清除命令行窗口
clear;      % 清除工作区变量，确保实验环境纯净

speed = 0;
% 加载外部参数配置文件（包含 BS_loc, Tx_rotation, BS_height, f 等）
run("parameters.m"); 

% ===== 随机选 A 点：以 BS 为中心，半径 [Rmin, Rmax] 米 =====
%{
rng(42);                 % 固定随机种子，保证可复现
Na   = 10;               % A点数量
Rmin = 30;               % 最小距离(米)
Rmax = 250;              % 最大距离(米)
bs_lat = BS_loc(1);
bs_lon = BS_loc(2);
% 均匀面积采样：r = sqrt(u*(Rmax^2-Rmin^2)+Rmin^2)
u = rand(Na,1);
r = sqrt(u*(Rmax^2 - Rmin^2) + Rmin^2);
theta = 2*pi*rand(Na,1);

dx = r .* cos(theta);    % 东西向(米)
dy = r .* sin(theta);    % 南北向(米)

A_lat = bs_lat + dy * lat2meter;
A_lon = bs_lon + dx * lont2meter;
%}
rng(42); 
A_points = [
    39.906535   116.403688
    39.907557   116.402229
    39.906371   116.400752
    39.905354   116.402234
    39.906372   116.403340
];

% A_points = [
%     39.906310   116.405150
%     39.906327   116.404960
%     39.906566   116.405164
%     39.906338   116.405170
% ];

disp(A_points);
save("A_points.mat", "A_points");

%% 地图加载与 Site Viewer 视图初始化
% 检查变量 viewer 是否存在且其句柄是否依然有效
if exist('viewer', 'var') && isvalid(viewer) 
    viewer.clearMap(); % 如果视图已打开，则清空地图上的现有站点和路径
else
    % 如果没有打开的视图，则根据 mapfile 创建新的 siteviewer 实例
    % 包含 OpenStreetMap 地图底图及建筑物模型
    viewer = siteviewer("Basemap", "openstreetmap", "Buildings", mapfile); 
    % === 相机位置：放在 UE 上方 ===
    campos(viewer, BS_loc(1)+400*lat2meter, BS_loc(2)+50*lont2meter, 300);  %  m 高空

    % === 相机朝向（非常关键）===
    camheading(viewer, 180);   % 朝南（试 90 / 180 / 270）
    campitch(viewer, -40);     % 俯视角（-90 是垂直向下）
    camroll(viewer, 0);
end

%% 基站 (Base Station) 站点参数设置
% 创建发射端对象，设置经纬度、天线偏转角、高度及中心频率
BS = txsite("Latitude", BS_loc(1), ...
            "Longitude", BS_loc(2), ...
            "AntennaAngle", Tx_rotation, ...
            "AntennaHeight", BS_height, ...  
            "TransmitterFrequency", f);

%% 生成信道数据并导出
% 保持 v2 流程：真实点 + 不同半径圆周取点，统计 NMSE/SGCS
load("A_points.mat","A_points");

for a = 1:size(A_points,1)
    UE_loc = A_points(a,:);   % 用作真实 A 点
    % d=1..10、theta_list 逻辑在 generate_v2.m 中执行

    d_list = (1:10) / 10;
    for d = d_list
        fprintf(">>> Generating data for d = %d m\n", d);
        run("generate_v2.m");

    % 保存结构与 v1 一致
        data = struct(); 
        data.NMSE_samples = nmse_samples;
        data.SGCS_samples = sgcs_samples;
        data.meta = struct( ...
            "speed", speed, ...
            "err_level", d, ...
            "err_percent", d, ...
            "A_idx", a, ...
            "A_loc", UE_loc, ...
            "Nmc", numel(nmse_samples), ...
            "Nerr", numel(nmse_samples) ...
        );

    % 动态生成文件名，例如 "v0.mat" 或 "v30.mat"
        d_str = strrep(sprintf("%.1f", d), '.', 'p');  % 0.1 → 0p1
        filename = sprintf("v%d_err%s_A%d.mat", speed, d_str, a);
        % filename = sprintf("v%d_err%d_A%d.mat", speed, d, a); 

    % 执行保存操作
        save(filename, "data");
    end
end
fprintf("已成功保存文件: %s\n", filename); % 在终端反馈进度


%disp("所有速度下的数据均已保存完毕！");



