%% step1_save_raytracing_db.m
% 1. 对 5 个真实点分别进行 ray tracing
% 2. 对每个真实点，在 d = 1:10 m 的圆周上取 360 个点继续 ray tracing
% 3. 保存真实点和误差点的多径物理参数数据库 RTDB
%
% 输出：
%   RTDB_5points_circle.mat

clc;
clear;

%% 读取参数
run("parameters.m");

%% 五个真实点
%A_points = [
%    22.580295   113.937917
%    22.580858   113.940297
%    22.581217   113.936915
%    22.580221   113.936778
%    22.5809     113.9370
%];

A_points = [
    22.583429   113.939846
    22.585297   113.938087
    22.584869   113.934705
    22.583103   113.932649
    22.581253   113.933428
];

%% 误差半径与圆周采样角
d_list = 1:10;
theta_list = 0:10:350;
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
%% 基站设置
BS = txsite("Latitude", BS_loc(1), ...
            "Longitude", BS_loc(2), ...
            "AntennaAngle", Tx_rotation, ...
            "AntennaHeight", BS_height, ...
            "TransmitterFrequency", f);

%% 射线追踪传播模型
pm = propagationModel("raytracing");
pm.AngularSeparation = "low";
pm.MaxNumReflections = MaxNumReflections;

%% 初始化结果结构体
RTDB = struct();

fprintf("========== 开始建立 Ray Tracing 参数数据库 ==========\n");

for a = 1:size(A_points,1)
    fprintf("\n>>> 正在处理第 %d/%d 个真实点\n", a, size(A_points,1));

    UE_loc_true = A_points(a,:);

    % 保存点编号
    RTDB(a).A_index = a;

    %% 1) 保存真实点
    RTDB(a).true = local_raytrace_one_point( ...
        BS, UE_loc_true, pm, UE_height, Rx_rotation);

    RTDB(a).true.d = 0;
    RTDB(a).true.theta_deg = NaN;

    %% 2) 保存误差圆周点
    for id = 1:length(d_list)
        d = d_list(id);
        fprintf("    -> 正在处理误差半径 d = %d m\n", d);

        RTDB(a).err(id).d = d;

        for it = 1:length(theta_list)
            theta_deg = theta_list(it);
            theta_rad = theta_deg * pi / 180;

            dx = d * cos(theta_rad);   % 东西方向，单位：m
            dy = d * sin(theta_rad);   % 南北方向，单位：m

            UE_loc_use = UE_loc_true;
            UE_loc_use(1) = UE_loc_true(1) + dy * lat2meter;
            UE_loc_use(2) = UE_loc_true(2) + dx * lont2meter;

            tmp = local_raytrace_one_point( ...
                BS, UE_loc_use, pm, UE_height, Rx_rotation);

            tmp.d = d;
            tmp.theta_deg = theta_deg;

            RTDB(a).err(id).points(it) = tmp;
        end
    end
end

save("RTDB_5points_circle.mat", "RTDB", "-v7.3");

fprintf("\n========== Ray Tracing 参数数据库已保存 ==========\n");
fprintf("保存文件：RTDB_5points_circle.mat\n");


%% =========================================================
% 局部函数：对单个位置点做 ray tracing，并提取路径参数
%% =========================================================
function out = local_raytrace_one_point(BS, UE_loc_use, pm, UE_height, Rx_rotation)

    UE = rxsite("Latitude", UE_loc_use(1), ...
                "Longitude", UE_loc_use(2), ...
                "AntennaHeight", UE_height, ...
                "AntennaAngle", Rx_rotation);

    rays = raytrace(BS, UE, pm);

    % 防止 rays 为空或格式异常
    has_rays = false;
    if ~isempty(rays)
        if iscell(rays)
            if ~isempty(rays{1})
                has_rays = true;
            end
        else
            if ~isempty(rays)
                has_rays = true;
            end
        end
    end

    out.loc = UE_loc_use;
    out.has_rays = has_rays;

    if ~has_rays
        out.numRays     = 0;
        out.AoA_az      = [];
        out.AoA_el      = [];
        out.ToA         = [];
        out.PathLoss    = [];
        out.PhaseShift  = [];
        out.PowerLinear = [];
        out.alpha       = [];
        return;
    end

    % MATLAB raytrace 输出通常是 rays{1}
    rr = rays{1};

    % 提取到达角（方位角、俯仰角）
    pathAoAs = [rr.AngleOfArrival];
    out.AoA_az = pathAoAs(1,:);
    out.AoA_el = pathAoAs(2,:);

    % 提取时延、路径损耗、相位
    out.ToA        = [rr.PropagationDelay];
    out.PathLoss   = [rr.PathLoss];
    out.PhaseShift = [rr.PhaseShift];

    out.numRays = numel(out.ToA);

    % 路径损耗(dB) -> 线性功率
    % 公式：P_linear = 10^(-PL/10)
    out.PowerLinear = 10.^(-out.PathLoss/10);

    % 基础复增益 alpha = sqrt(P) * exp(j*phi)
    out.alpha = sqrt(out.PowerLinear) .* exp(1j * out.PhaseShift);
end