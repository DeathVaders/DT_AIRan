function [east_unit, north_unit] = get_direction_vectors()
    % 从地图数据计算东向和北向的单位矢量（1米长度）
    % 返回值：
    %   east_unit: [d_lat_east, d_lon_east]，1米对应的纬度、经度变化
    %   north_unit: [d_lat_north, d_lon_north]，1米对应的纬度、经度变化
    
    R = 6371000;  % 地球半径，米
    
    % 从地图中提取道路端点
    % 南北向道路（用于确定北向）
    lat_ns_start = 39.89848004;  % 节点1纬度
    lon_ns_start = 116.39920171; % 节点1经度
    lat_ns_end = 39.91052196;    % 节点2纬度
    lon_ns_end = 116.39920171;   % 节点2经度
    
    % 东西向道路（用于确定东向）
    lat_ew_start = 39.89865991;  % 节点9纬度
    lon_ew_start = 116.39896725; % 节点9经度
    lat_ew_end = 39.89865991;    % 节点10纬度
    lon_ew_end = 116.40822875;   % 节点10经度
    
    % 计算地图中心纬度（用于东向矢量计算）
    lat_center = (lat_ns_start + lat_ns_end) / 2;
    
    % 计算北向单位矢量（1米向北对应的纬度变化）
    % 注意：在球面上，1度纬度对应的距离是固定的
    north_vector_lat = 1 / (R * pi / 180);  % 1米对应的纬度变化（度）
    north_vector_lon = 0;  % 北向不改变经度
    
    % 计算东向单位矢量（1米向东对应的经度变化）
    % 1度经度对应的距离 = R * cos(latitude) * pi/180
    distance_per_degree_lon = R * cosd(lat_center) * pi / 180;
    east_vector_lon = 1 / distance_per_degree_lon;  % 1米对应的经度变化（度）
    east_vector_lat = 0;  % 东向不改变纬度
    
    % 返回单位矢量
    east_unit = [east_vector_lat, east_vector_lon];  % [纬度/米, 经度/米]
    north_unit = [north_vector_lat, north_vector_lon];
    
    % 显示结果
    fprintf('=== 地图方向信息 ===\n');
    fprintf('地图中心纬度: %.6f°\n', lat_center);
    fprintf('1度纬度对应: %.2f 米\n', R * pi / 180);
    fprintf('1度经度对应: %.2f 米（在纬度%.2f°处）\n', distance_per_degree_lon, lat_center);
    fprintf('\n');
    fprintf('东向1米单位矢量:\n');
    fprintf('  纬度变化: %.10f 度\n', east_unit(1));
    fprintf('  经度变化: %.10f 度\n', east_unit(2));
    fprintf('\n');
    fprintf('北向1米单位矢量:\n');
    fprintf('  纬度变化: %.10f 度\n', north_unit(1));
    fprintf('  经度变化: %.10f 度\n', north_unit(2));
    
    % 验证道路方向
    % 计算南北向道路的实际距离
    dlat_ns = deg2rad(lat_ns_end - lat_ns_start);
    a_ns = sin(dlat_ns/2)^2;
    c_ns = 2 * atan2(sqrt(a_ns), sqrt(1 - a_ns));
    dist_ns_actual = R * c_ns;
    
    % 计算东西向道路的实际距离
    dlon_ew = deg2rad(lon_ew_end - lon_ew_start);
    a_ew = cosd(lat_ew_start)^2 * sin(dlon_ew/2)^2;
    c_ew = 2 * atan2(sqrt(a_ew), sqrt(1 - a_ew));
    dist_ew_actual = R * c_ew;
    
    fprintf('\n=== 道路方向验证 ===\n');
    fprintf('南北向道路长度: %.2f 米\n', dist_ns_actual);
    fprintf('  方向: 正北方向（经度不变）\n');
    fprintf('东西向道路长度: %.2f 米\n', dist_ew_actual);
    fprintf('  方向: 正东方向（纬度不变）\n');
end