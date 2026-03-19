%% step1_save_manual_db.m
% Manually construct a 5-group RT database.
% Each group contains 4 parameter types with 6 path cases.

clc;
clear;

%% Initialize output database
RTDB = struct();

%% Manually define 5 groups, 6 rays per group
manual_sets(1).AoA_az = [-40, -18, 0, 20, 38, 55];
manual_sets(1).AoA_el = [60, 52, 42, 34, 25, 18];
manual_sets(1).ToA = [50e-9, 105e-9, 160e-9, 225e-9, 300e-9, 380e-9];
manual_sets(1).alpha = [
    1.00e-5 * exp(1j * 0.20 * pi), ...
    0.86e-5 * exp(1j * 0.48 * pi), ...
    0.72e-5 * exp(1j * 0.75 * pi), ...
    0.60e-5 * exp(1j * 1.00 * pi), ...
    0.46e-6 * exp(1j * 1.25 * pi), ...
    0.32e-6 * exp(1j * 1.60 * pi)
];

manual_sets(2).AoA_az = [-55, -30, -12, 8, 30, 46];
manual_sets(2).AoA_el = [68, 56, 45, 36, 28, 20];
manual_sets(2).ToA = [70e-9, 120e-9, 180e-9, 245e-9, 320e-9, 395e-9];
manual_sets(2).alpha = [
    1.00e-5 * exp(1j * 0.30 * pi), ...
    0.84e-5 * exp(1j * 0.62 * pi), ...
    0.70e-5 * exp(1j * 0.95 * pi), ...
    0.59e-5 * exp(1j * 1.18 * pi), ...
    0.48e-6 * exp(1j * 1.40 * pi), ...
    0.30e-6 * exp(1j * 1.70 * pi)
];

manual_sets(3).AoA_az = [-25, -5, 18, 34, 55, 70];
manual_sets(3).AoA_el = [58, 47, 38, 30, 22, 16];
manual_sets(3).ToA = [40e-9, 92e-9, 140e-9, 205e-9, 280e-9, 360e-9];
manual_sets(3).alpha = [
    1.00e-5 * exp(1j * 0.15 * pi), ...
    0.82e-5 * exp(1j * 0.52 * pi), ...
    0.68e-5 * exp(1j * 0.85 * pi), ...
    0.56e-5 * exp(1j * 1.08 * pi), ...
    0.42e-6 * exp(1j * 1.35 * pi), ...
    0.28e-6 * exp(1j * 1.72 * pi)
];

manual_sets(4).AoA_az = [-62, -38, -20, 0, 22, 40];
manual_sets(4).AoA_el = [72, 61, 50, 40, 30, 22];
manual_sets(4).ToA = [90e-9, 145e-9, 210e-9, 275e-9, 340e-9, 420e-9];
manual_sets(4).alpha = [
    1.00e-5 * exp(1j * 0.25 * pi), ...
    0.87e-5 * exp(1j * 0.56 * pi), ...
    0.74e-5 * exp(1j * 0.90 * pi), ...
    0.63e-5 * exp(1j * 1.06 * pi), ...
    0.50e-5 * exp(1j * 1.30 * pi), ...
    0.34e-6 * exp(1j * 1.58 * pi)
];

manual_sets(5).AoA_az = [-35, -10, 10, 28, 48, 63];
manual_sets(5).AoA_el = [66, 54, 44, 35, 26, 18];
manual_sets(5).ToA = [60e-9, 118e-9, 190e-9, 250e-9, 310e-9, 390e-9];
manual_sets(5).alpha = [
    1.00e-5 * exp(1j * 0.18 * pi), ...
    0.85e-5 * exp(1j * 0.58 * pi), ...
    0.71e-5 * exp(1j * 1.00 * pi), ...
    0.58e-6 * exp(1j * 1.22 * pi), ...
    0.47e-6 * exp(1j * 1.50 * pi), ...
    0.31e-6 * exp(1j * 1.80 * pi)
];

%% Fill RTDB
for a = 1:5
    aoa_az = manual_sets(a).AoA_az;
    aoa_el = manual_sets(a).AoA_el;
    toa = manual_sets(a).ToA;
    alpha = manual_sets(a).alpha;
    num_rays = numel(alpha);

    % Auto-compute derived fields from alpha
    power_linear = abs(alpha).^2;
    phase_shift = angle(alpha);
    path_loss = -10 * log10(power_linear);

    RTDB(a).A_index = a;
    RTDB(a).true.loc = [a, a];
    RTDB(a).true.has_rays = true;
    RTDB(a).true.numRays = num_rays;
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
    fprintf("  numRays      : %d\n", RTDB(a).true.numRays);
    fprintf("  AoA_az (deg) : %s\n", mat2str(RTDB(a).true.AoA_az, 4));
    fprintf("  AoA_el (deg) : %s\n", mat2str(RTDB(a).true.AoA_el, 4));
    fprintf("  ToA (ns)     : %s\n", mat2str(RTDB(a).true.ToA * 1e9, 4));
    fprintf("  |alpha|      : %s\n", mat2str(abs(RTDB(a).true.alpha), 4));
    fprintf("  phase (rad)  : %s\n", mat2str(RTDB(a).true.PhaseShift, 4));
    fprintf("  PathLoss (dB): %s\n", mat2str(RTDB(a).true.PathLoss, 4));
end
