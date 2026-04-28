clc;        % 清空命令行输出
clear;      % 清空工作区变量
rng(42);
speed = 0;

% 加载外部参数配置文件（包含 BS_locs、UE_points_by_BS、UE_directions_by_BS 等）
run("parameters.m");
run("material_config.m");
if SCATTERER_ENABLE
    build_scatterer_map(mapfile, SCATTERER_MAPFILE, SCATTERER_DENSITY, lat2meter, lont2meter, SCATTERER_FACE_MODE, SCATTERER_EXTRA_FACES, ...
        BUILDING_MATERIAL_NAME, GROUND_MATERIAL_NAME, LAMP_MATERIAL_NAME, VEHICLE_MATERIAL_NAME, PEDESTRIAN_MATERIAL_NAME);
    mapfile = SCATTERER_MAPFILE;
end

visualize_dir = fullfile(fileparts(pwd), "visualize");
if isempty(which("get_direction_vectors")) && isfolder(visualize_dir)
    addpath(visualize_dir);
end
[east_unit, north_unit] = get_direction_vectors();

sim_pairs = [];
for bs_idx = 1:size(BS_locs, 1)
    ue_points = UE_points_by_BS{bs_idx};
    for ue_idx = 1:size(ue_points, 1)
        sim_pairs = [sim_pairs; bs_idx, ue_idx]; 
    end
end

save("A_points.mat", "UE_points_by_BS", "UE_directions_by_BS", "BS_locs", "sim_pairs");

%% 绘制地图 Site Viewer
if exist('viewer', 'var') && isvalid(viewer)
    viewer.clearMap();
else
    viewer = siteviewer("Basemap", "openstreetmap", "Buildings", mapfile);
    campos(viewer, BS_locs(1, 1) + 400 * lat2meter, BS_locs(1, 2) + 50 * lont2meter, 300);
    camheading(viewer, 180);
    campitch(viewer, -40);
    camroll(viewer, 0);
end

%% 主循环：逐个 BS、逐个 UE 真实位置，计算沿街道双向定位误差下的信道指标
load("A_points.mat", "UE_points_by_BS", "UE_directions_by_BS", "BS_locs", "sim_pairs");

d_list = 0:5;

for bs_idx = 1:size(BS_locs, 1)
    BS_loc = BS_locs(bs_idx, :);
    BS = txsite("Latitude", BS_loc(1), ...
                "Longitude", BS_loc(2), ...
                "AntennaAngle", Tx_rotation, ...
                "AntennaHeight", BS_height, ...
                "TransmitterFrequency", f);

    UE_points = UE_points_by_BS{bs_idx};
    UE_directions = string(UE_directions_by_BS{bs_idx});
    for ue_idx = 1:size(UE_points, 1)
        UE_loc = UE_points(ue_idx, :);
        UE_direction = UE_directions(ue_idx);

        for d = d_list
            fprintf(">>> Generating data for BS%d UE%d, dir = %s, d = %.1f m\n", bs_idx, ue_idx, UE_direction, d);
            run("generate_v2.m");

            data = struct();
            data.NMSE_samples = nmse_samples;
            data.SGCS_samples = sgcs_samples;
            data.PDP_COS_samples = pdp_cos_samples;
            data.AZ_COS_samples = az_cos_samples;
            data.EL_COS_samples = el_cos_samples;
            data.meta = struct( ...
                "speed", speed, ...
                "err_level", d, ...
                "err_percent", d, ...
                "BS_idx", bs_idx, ...
                "UE_idx", ue_idx, ...
                "BS_loc", BS_loc, ...
                "UE_loc", UE_loc, ...
                "UE_direction", UE_direction, ...
                "err_points", err_points, ...
                "Nmc", numel(nmse_samples), ...
                "Nerr", numel(nmse_samples) ...
            );

            d_str = strrep(sprintf("%.1f", d), '.', 'p');
            filename = sprintf("v%d_err%s_BS%dUE%d.mat", speed, d_str, bs_idx, ue_idx);
            save(filename, "data");
        end
    end
end
fprintf("完整结果已保存，最后一个文件： %s\n", filename);
