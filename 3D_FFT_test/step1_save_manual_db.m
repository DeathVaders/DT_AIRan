%% step1_save_manual_db.m
% 手动构造 5 组多径参数，并保存为与 step1_save_raytracing_db.m
% 中 RTDB(a).true 字段结构兼容的数据库文件。

clc;
clear;

%% 初始化数据库
RTDB = struct();

%% 定义五组固定参数
manual_sets(1).AoA_az = [-40, 0, 38];
manual_sets(1).AoA_el = [60, 42, 25];
manual_sets(1).ToA = [50e-9, 160e-9, 300e-9];
manual_sets(1).alpha = [
    1.00 * exp(1j * 0.20 * pi), ...
    0.72 * exp(1j * 0.75 * pi), ...
    0.46 * exp(1j * 1.25 * pi)
];

manual_sets(2).AoA_az = [-55, -12, 30];
manual_sets(2).AoA_el = [68, 45, 28];
manual_sets(2).ToA = [70e-9, 180e-9, 320e-9];
manual_sets(2).alpha = [
    1.00 * exp(1j * 0.30 * pi), ...
    0.70 * exp(1j * 0.95 * pi), ...
    0.48 * exp(1j * 1.40 * pi)
];

manual_sets(3).AoA_az = [-25, 18, 55];
manual_sets(3).AoA_el = [58, 38, 22];
manual_sets(3).ToA = [40e-9, 140e-9, 280e-9];
manual_sets(3).alpha = [
    1.00 * exp(1j * 0.15 * pi), ...
    0.68 * exp(1j * 0.85 * pi), ...
    0.42 * exp(1j * 1.35 * pi)
];

manual_sets(4).AoA_az = [-62, -20, 22];
manual_sets(4).AoA_el = [72, 50, 30];
manual_sets(4).ToA = [90e-9, 210e-9, 340e-9];
manual_sets(4).alpha = [
    1.00 * exp(1j * 0.25 * pi), ...
    0.74 * exp(1j * 0.90 * pi), ...
    0.50 * exp(1j * 1.30 * pi)
];

manual_sets(5).AoA_az = [-35, 10, 48];
manual_sets(5).AoA_el = [66, 44, 26];
manual_sets(5).ToA = [60e-9, 190e-9, 310e-9];
manual_sets(5).alpha = [
    1.00 * exp(1j * 0.18 * pi), ...
    0.71 * exp(1j * 1.00 * pi), ...
    0.47 * exp(1j * 1.50 * pi)
];

%% Fill RTDB
for a = 1:5
    aoa_az = manual_sets(a).AoA_az;
    aoa_el = manual_sets(a).AoA_el;
    toa = manual_sets(a).ToA;
    alpha = manual_sets(a).alpha;

    % Auto-compute derived fields from alpha
    power_linear = abs(alpha).^2;
    phase_shift = angle(alpha);
    path_loss = -10 * log10(power_linear);

    RTDB(a).A_index = a;
    RTDB(a).true.loc = [a, a];
    RTDB(a).true.has_rays = true;
    RTDB(a).true.numRays = 3;
    RTDB(a).true.AoA_az = aoa_az;
    RTDB(a).true.AoA_el = aoa_el;
    RTDB(a).true.ToA = toa;
    RTDB(a).true.PathLoss = path_loss;
    RTDB(a).true.PhaseShift = phase_shift;
    RTDB(a).true.PowerLinear = power_linear;
    RTDB(a).true.alpha = alpha;
    RTDB(a).true.d = 0;
    RTDB(a).true.theta_deg = NaN;
end

%% Save database
save("RTDB_manual_5groups.mat", "RTDB", "-v7.3");

%% Print a short summary for checking
fprintf("========== Manual RTDB generated ==========\n");
fprintf("Saved file: RTDB_manual_5groups.mat\n");

for a = 1:5
    fprintf("\nGroup %d:\n", a);
    fprintf("  AoA_az (deg) : [%6.1f %6.1f %6.1f]\n", RTDB(a).true.AoA_az);
    fprintf("  AoA_el (deg) : [%6.1f %6.1f %6.1f]\n", RTDB(a).true.AoA_el);
    fprintf("  ToA (ns)     : [%6.1f %6.1f %6.1f]\n", RTDB(a).true.ToA * 1e9);
    fprintf("  |alpha|      : [%6.3f %6.3f %6.3f]\n", abs(RTDB(a).true.alpha));
    fprintf("  phase (rad)  : [%6.3f %6.3f %6.3f]\n", RTDB(a).true.PhaseShift);
    fprintf("  PathLoss (dB): [%6.3f %6.3f %6.3f]\n", RTDB(a).true.PathLoss);
end
