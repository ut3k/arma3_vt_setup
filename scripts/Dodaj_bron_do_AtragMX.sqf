private _unit = player;
private _weapon = currentWeapon _unit;
private _magazine = currentMagazine _unit;
if (_weapon isEqualTo "" || {_magazine isEqualTo ""}) exitWith {systemChat "No weapon or magazine";};

private _ammo = getText (configFile >> "CfgMagazines" >> _magazine >> "ammo");
if (_ammo isEqualTo "") exitWith {systemChat "No ammo class";};

private _fnc_interpolate = {
    params ["_x", "_xArray", "_yArray"];
    private _count = count _xArray;
    if (_count == 0) exitWith {0};
    if (_count == 1) exitWith {_yArray select 0};
    if (_x <= (_xArray select 0)) exitWith {_yArray select 0};
    if (_x >= (_xArray select (_count - 1))) exitWith {_yArray select (_count - 1)};
    private _i = 0;
    while {_i < _count - 1 && {_x > (_xArray select (_i + 1))}} do {_i = _i + 1};
    private _x0 = _xArray select _i;
    private _x1 = _xArray select (_i + 1);
    private _y0 = _yArray select _i;
    private _y1 = _yArray select (_i + 1);
    _y0 + (_y1 - _y0) * ((_x - _x0) / (_x1 - _x0 max 0.0001))
};

private _initSpeed = getNumber (configFile >> "CfgMagazines" >> _magazine >> "initSpeed");
if (_initSpeed <= 0) then {
    _initSpeed = getNumber (configFile >> "CfgAmmo" >> _ammo >> "initSpeed");
};
private _weaponInitSpeed = getNumber (configFile >> "CfgWeapons" >> _weapon >> "initSpeed");
if (_weaponInitSpeed > 0) then {
    _initSpeed = _weaponInitSpeed;
} else {
    if (_weaponInitSpeed < 0) then {
        _initSpeed = _initSpeed * abs _weaponInitSpeed;
    };
};
private _baseMV = _initSpeed;

private _barrelLengths = getArray (configFile >> "CfgAmmo" >> _ammo >> "ACE_barrelLengths");
private _muzzleVelocities = getArray (configFile >> "CfgAmmo" >> _ammo >> "ACE_muzzleVelocities");
private _weaponBarrelLength = getNumber (configFile >> "CfgWeapons" >> _weapon >> "ACE_barrelLength");
if (_weaponBarrelLength <= 0) then {_weaponBarrelLength = 400};

if ((count _barrelLengths > 0) && {(count _muzzleVelocities) isEqualTo (count _barrelLengths)}) then {
    private _barrelMV = [_weaponBarrelLength, _barrelLengths, _muzzleVelocities] call _fnc_interpolate;
    _baseMV = _baseMV + (_barrelMV - _baseMV);
};

private _tempShifts = getArray (configFile >> "CfgAmmo" >> _ammo >> "ACE_ammoTempMuzzleVelocityShifts");
private _hasTempData = (count _tempShifts >= 11);
private _temps = [-15, 0, 10, 15, 25, 30, 35];
private _mvTable = [];
{
    private _t = _x;
    private _shift = 0;
    if (_hasTempData) then {
        private _idx = ((_t + 15) / 5) max 0 min 10;
        private _i0 = floor _idx;
        private _i1 = ceil _idx;
        private _s0 = _tempShifts select _i0;
        private _s1 = _tempShifts select _i1;
        _shift = _s0 + (_s1 - _s0) * (_idx - _i0);
    };
    _mvTable pushBack [_t, _baseMV + _shift];
} forEach _temps;

private _cal = getNumber (configFile >> "CfgAmmo" >> _ammo >> "ACE_caliber");
if (_cal <= 0) then {_cal = 7.62};
private _massG = getNumber (configFile >> "CfgAmmo" >> _ammo >> "ACE_bulletMass");
private _grains = if (_massG > 0) then {round (_massG * 15.432)} else {0};
private _display = getText (configFile >> "CfgMagazines" >> _magazine >> "displayName");
if (_display isEqualTo "") then {_display = _ammo};
_display = toUpper _display;
private _profileName = format ["%1.%2.%3", round (_cal * 10) / 10, _grains, _display];
if (count _profileName > 20) then {_profileName = _profileName select [0, 20]};

private _bulletMass = _massG;
if (_bulletMass <= 0) then {_bulletMass = 10};
private _twist = getNumber (configFile >> "CfgWeapons" >> _weapon >> "ACE_barrelTwist");
if (_twist <= 0) then {_twist = 254};
private _bc = 0.4;
private _bcs = getArray (configFile >> "CfgAmmo" >> _ammo >> "ACE_ballisticCoefficients");
if (count _bcs > 0) then {_bc = _bcs select 0};
private _dragModel = getNumber (configFile >> "CfgAmmo" >> _ammo >> "ACE_dragModel");
if (_dragModel <= 0) then {_dragModel = 1};
private _airFriction = getNumber (configFile >> "CfgAmmo" >> _ammo >> "airFriction");
private _atmosphere = getText (configFile >> "CfgAmmo" >> _ammo >> "ACE_standardAtmosphere");
if (_atmosphere isEqualTo "") then {_atmosphere = "ICAO"};
private _boreHeight = 3.81;

private _preset = [
    _profileName,
    _baseMV,
    100,
    0,
    _airFriction,
    _boreHeight,
    0,
    2,
    10,
    120,
    0,
    0,
    _bulletMass,
    _cal,
    _twist,
    _bc,
    _dragModel,
    _atmosphere,
    _mvTable,
    [[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0]],
    true
];

if (isNil "ace_atragmx_gunList") then {
    systemChat "Open ATragMX once first";
} else {
    private _idx = -1;
    {
        if ((_x select 0) isEqualTo _profileName) exitWith {_idx = _forEachIndex};
    } forEach ace_atragmx_gunList;
    if (_idx >= 0) then {
        ace_atragmx_gunList set [_idx, _preset];
    } else {
        ace_atragmx_gunList pushBack _preset;
    };
    profileNamespace setVariable ["ACE_ATragMX_gunList", ace_atragmx_gunList];
    saveProfileNamespace;
    systemChat format ["Added: %1 | baseMV %1 m/s | temp: %2", _profileName, _baseMV, if (_hasTempData) then {"YES"} else {"NO"}];
};