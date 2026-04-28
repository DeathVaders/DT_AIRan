%% 材质配置：双模式切换
% MATERIAL_MODE:
%   'custom' -> 纯 custom（建筑类几何统一一组电参数 + 地面单独一组）
%   'auto'   -> 纯 auto（建筑/地面/散射体按 OSM tag 分类）
%
% 说明：MATLAB 当前单次 raytrace 下，custom 模式无法让建筑/车辆/路灯/行人
% 分别拥有独立 custom 电参数；因此 custom 模式中所有 building 类几何
% （建筑+散射体）共用一组参数。auto 模式则支持按对象分类独立材质。

% MATERIAL_MODE = 'custom';   % 'custom' | 'auto'
MATERIAL_MODE = 'auto';   % 'custom' | 'auto'
MANUAL_GROUND_ONLY = true; % true: 关闭 terrain，只保留 OSM 手动地板

%% ===== auto 模式：按 OSM 材质名分类 =====
BUILDING_MATERIAL_NAME   = 'concrete';
GROUND_MATERIAL_NAME     = 'concrete';
LAMP_MATERIAL_NAME       = 'metal';
VEHICLE_MATERIAL_NAME    = 'metal';
PEDESTRIAN_MATERIAL_NAME = 'water';
GROUND_TERRAIN_MATERIAL = GROUND_MATERIAL_NAME;
% % TerrainMaterial 不支持 asphalt / auto，做兼容映射
% if strcmp(GROUND_MATERIAL_NAME, 'asphalt')
%     GROUND_TERRAIN_MATERIAL = 'concrete';
% else
    
% end

%% ===== custom 模式：按电磁常数设置 =====
% 建筑
CUSTOM_BUILDING_EPSR  = 5.3;
CUSTOM_BUILDING_SIGMA = 0.02;
% 地面
CUSTOM_GROUND_EPSR  = 4.0;
CUSTOM_GROUND_SIGMA = 0.02;
% 散射体（记录值）
CUSTOM_VEHICLE_EPSR    = 5.0;
CUSTOM_VEHICLE_SIGMA   = 0.05;
CUSTOM_LAMP_EPSR       = 2.0;
CUSTOM_LAMP_SIGMA      = 50;
CUSTOM_PEDESTRIAN_EPSR = 15.0;
CUSTOM_PEDESTRIAN_SIGMA= 1.0;
% 当前接口限制下，custom 模式只能给所有 building 类几何统一一组参数。
% 这里取“散射体统一参数”，用于建筑散射体合并建模。
CUSTOM_SCATTERER_EPSR  = 5.0;
CUSTOM_SCATTERER_SIGMA = 0.05;

%% ===== 散射体配置 =====
SCATTERER_ENABLE = true;
SCATTERER_DENSITY = 'low';
% SCATTERER_DENSITY = 'medium';
% SCATTERER_DENSITY = 'high';
SCATTERER_MAPFILE = '3gpp_urban_grid_scatter.osm';
SCATTERER_FACE_MODE = 'multi';
SCATTERER_EXTRA_FACES = 2;

fprintf('\n========== Material 配置 ==========\n');
fprintf('Mode      : %s\n', MATERIAL_MODE);
if strcmpi(MATERIAL_MODE, 'auto')
    fprintf('Building  : %s\n', BUILDING_MATERIAL_NAME);
    fprintf('Ground    : %s (terrain-> %s)\n', GROUND_MATERIAL_NAME, GROUND_TERRAIN_MATERIAL);
    fprintf('Lamp      : %s\n', LAMP_MATERIAL_NAME);
    fprintf('Vehicle   : %s\n', VEHICLE_MATERIAL_NAME);
    fprintf('Pedestrian: %s\n', PEDESTRIAN_MATERIAL_NAME);
else
    fprintf('Building custom  : epsr=%.3f sigma=%.3g\n', CUSTOM_BUILDING_EPSR, CUSTOM_BUILDING_SIGMA);
    % fprintf('Ground custom    : epsr=%.3f sigma=%.3g\n', CUSTOM_GROUND_EPSR, CUSTOM_GROUND_SIGMA);
    % fprintf('Scatterer custom : epsr=%.3f sigma=%.3g\n', CUSTOM_SCATTERER_EPSR, CUSTOM_SCATTERER_SIGMA);
    % fprintf('Vehicle ref      : epsr=%.3f sigma=%.3g\n', CUSTOM_VEHICLE_EPSR, CUSTOM_VEHICLE_SIGMA);
    % fprintf('Lamp ref         : epsr=%.3f sigma=%.3g\n', CUSTOM_LAMP_EPSR, CUSTOM_LAMP_SIGMA);
    % fprintf('Pedestrian ref   : epsr=%.3f sigma=%.3g\n', CUSTOM_PEDESTRIAN_EPSR, CUSTOM_PEDESTRIAN_SIGMA);
end
fprintf('Scatterer : %s | extra faces = %d\n', SCATTERER_FACE_MODE, SCATTERER_EXTRA_FACES);
fprintf('===================================\n\n');
