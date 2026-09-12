private _unit = player;
private _weapon = currentWeapon _unit;
private _magazine = currentMagazine _unit;

if (_weapon isEqualTo "" || {_magazine isEqualTo ""}) exitWith {
    systemChat "No weapon or magazine";
};

private _magCfg = configFile >> "CfgMagazines" >> _magazine;
private _weaponCfg = configFile >> "CfgWeapons" >> _weapon;
private _ammo = getText (_magCfg >> "ammo");

if (_ammo isEqualTo "") exitWith {
    systemChat "No ammo class";
};

private _ammoCfg = configFile >> "CfgAmmo" >> _ammo;

private _fnc_interpolate = {
    params ["_x", "_xArray", "_yArray"];
    private _count = count _xArray;
    if (_count isEqualTo 0) exitWith {0};
    if (_count isEqualTo 1) exitWith {_yArray select 0};
    if (_x <= (_xArray select 0)) exitWith {_yArray select 0};
    if (_x >= (_xArray select (_count - 1))) exitWith {_yArray select (_count - 1)};
    private _i = 0;
    while { _i < (_count - 1) && {_x > (_xArray select (_i + 1))} } do {
        _i = _i + 1;
    };
    private _x0 = _xArray select _i;
    private _x1 = _xArray select (_i + 1);
    private _y0 = _yArray select _i;
    private _y1 = _yArray select (_i + 1);
    _y0 + (_y1 - _y0) * ((_x - _x0) / ((_x1 - _x0) max 0.0001))
};

private _fnc_g7ToC1 = {
    params ["_bcG7", "_velocity"];
    private _mach = _velocity / 340.3;
    private _g1M = [0,0.05,0.10,0.15,0.20,0.25,0.30,0.35,0.40,0.45,0.50,0.55,0.60,0.65,0.70,0.725,0.75,0.775,0.80,0.825,0.85,0.875,0.90,0.925,0.95,0.975,1.0,1.025,1.05,1.075,1.10,1.125,1.15,1.175,1.20,1.225,1.25,1.275,1.30,1.35,1.40,1.50,1.60,1.80,2.00,2.20,2.40,2.60,3.00,3.60,4.00,5.00];
    private _g1C = [0.2629,0.2558,0.2487,0.2413,0.2344,0.2278,0.2214,0.2155,0.2104,0.2061,0.2032,0.2020,0.2034,0.2065,0.2122,0.2161,0.2207,0.2257,0.2313,0.2375,0.2443,0.2517,0.2597,0.2682,0.2772,0.2866,0.2960,0.3054,0.3145,0.3232,0.3313,0.3389,0.3458,0.3522,0.3580,0.3633,0.3681,0.3724,0.3763,0.3829,0.3884,0.3976,0.4053,0.4180,0.4284,0.4372,0.4448,0.4514,0.4626,0.4760,0.4838,0.5000];
    private _g7C = [0.1198,0.1197,0.1196,0.1195,0.1194,0.1194,0.1194,0.1194,0.1194,0.1195,0.1196,0.1197,0.1198,0.1199,0.1201,0.1203,0.1205,0.1208,0.1215,0.1233,0.1268,0.1306,0.1352,0.1405,0.1464,0.1529,0.1598,0.1671,0.1743,0.1812,0.1876,0.1935,0.1987,0.2033,0.2074,0.2110,0.2142,0.2171,0.2196,0.2238,0.2270,0.2316,0.2348,0.2379,0.2397,0.2406,0.2409,0.2407,0.2394,0.2359,0.2334,0.2280];
    private _cd1 = [_mach, _g1M, _g1C] call _fnc_interpolate;
    private _cd7 = [_mach, _g1M, _g7C] call _fnc_interpolate;
    _bcG7 * _cd1 / _cd7
};

private _initSpeed = getNumber (_magCfg >> "initSpeed");
if (_initSpeed <= 0) then {
    _initSpeed = getNumber (_ammoCfg >> "initSpeed");
};

private _weaponInitSpeed = getNumber (_weaponCfg >> "initSpeed");
private _muzzle = currentMuzzle _unit;
private _muzzleCfg = if (_muzzle isEqualTo "" || {!isClass (_weaponCfg >> _muzzle)}) then {
    _weaponCfg
} else {
    _weaponCfg >> _muzzle
};
private _muzzleInitSpeed = getNumber (_muzzleCfg >> "initSpeed");
if (_muzzleInitSpeed != 0) then {
    _weaponInitSpeed = _muzzleInitSpeed;
};
if (_weaponInitSpeed > 0) then {
    _initSpeed = _weaponInitSpeed;
};
if (_weaponInitSpeed < 0) then {
    _initSpeed = _initSpeed * abs _weaponInitSpeed;
};

private _baseMV = _initSpeed;
private _barrelLengths = getArray (_ammoCfg >> "ACE_barrelLengths");
private _muzzleVelocities = getArray (_ammoCfg >> "ACE_muzzleVelocities");
private _weaponBarrelLength = getNumber (_weaponCfg >> "ACE_barrelLength");
private _muzzleBarrelLength = getNumber (_muzzleCfg >> "ACE_barrelLength");
if (_muzzleBarrelLength > 0) then {
    _weaponBarrelLength = _muzzleBarrelLength;
};

private _hasBarrelData = (count _barrelLengths > 0) && ((count _barrelLengths) isEqualTo (count _muzzleVelocities));
if (_hasBarrelData) then {
    if (_weaponBarrelLength <= 0) then {
        _weaponBarrelLength = _barrelLengths select (count _barrelLengths - 1);
    };
    _baseMV = [ _weaponBarrelLength, _barrelLengths, _muzzleVelocities ] call _fnc_interpolate;
};

private _tempShifts = getArray (_ammoCfg >> "ACE_ammoTempMuzzleVelocityShifts");
private _hasTempData = (count _tempShifts) >= 11;
private _aceTemps = [-15,-10,-5,0,5,10,15,20,25,30,35];
private _temps = [-15,0,10,15,25,30,35];
private _mvTable = [];

{
    private _temperature = _x;
    private _shift = 0;
    if (_hasTempData) then {
        _shift = [ _temperature, _aceTemps, _tempShifts ] call _fnc_interpolate;
    };
    _mvTable pushBack [ _temperature, _baseMV + _shift ];
} forEach _temps;

private _caliber = getNumber (_ammoCfg >> "ACE_caliber");
if (_caliber <= 0) then {
    _caliber = 7.62;
};

private _bulletMass = getNumber (_ammoCfg >> "ACE_bulletMass");
if (_bulletMass <= 0) then {
    _bulletMass = 10;
};

private _grains = round (_bulletMass * 15.4323584);

private _twistRaw = getNumber (_weaponCfg >> "ACE_barrelTwist");
private _twistCm = 25.4;
private _twistSource = "default";
if (_twistRaw > 0) then {
    if (_twistRaw < 100) then {
        _twistCm = _twistRaw * 2.54;
        _twistSource = "inches";
    } else {
        _twistCm = _twistRaw / 10;
        _twistSource = "mm";
    };
};

private _bcs = getArray (_ammoCfg >> "ACE_ballisticCoefficients");
private _bounds = getArray (_ammoCfg >> "ACE_velocityBoundaries");
private _dragModel = getNumber (_ammoCfg >> "ACE_dragModel");
private _bc = 0;
private _c1Table = [[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0]];
private _bcSource = "none";

if ((count _bcs) > 0) then {
    _bc = _bcs select 0;
    if (_dragModel isEqualTo 7 && {_bc > 0}) then {
        private _n = count _bcs;
        if (_n > 1 && {(count _bounds) >= (_n - 1)}) then {
            private _v = _baseMV;
            private _bi = 0;
            while { _bi < (_n - 1) && {_v < (_bounds select _bi)} } do {
                _bi = _bi + 1;
            };
            _bc = _bcs select _bi;
        };
        private _ranges = [0,300,600,900,1200,1500,1800];
        private _af = abs (getNumber (_ammoCfg >> "airFriction"));
        if (_af <= 0) then { _af = 0.000357 };
        private _v = _baseMV;
        _c1Table = _ranges apply {
            private _r = _x;
            private _c1 = [_bc, _v] call _fnc_g7ToC1;
            _v = _v * exp (-_af * _r);
            [_r, _c1]
        };
        _bc = _c1Table select 0 select 1;
        _dragModel = 1;
        _bcSource = "G7 converted";
    } else {
        _dragModel = 1;
        _bcSource = "native C1";
    };
};

private _airFriction = getNumber (_ammoCfg >> "airFriction");
private _atmosphere = getText (_ammoCfg >> "ACE_standardAtmosphere");
if (_atmosphere isEqualTo "") then {
    _atmosphere = "ICAO";
};

private _projectileName = getText (_ammoCfg >> "displayName");
if (_projectileName isEqualTo "") then {
    _projectileName = getText (_magCfg >> "displayName");
};
if (_projectileName isEqualTo "") then {
    _projectileName = _ammo;
};

private _projectileChars = toArray (toUpper _projectileName);
private _cleanChars = [];

{
    if ( (_x >= 48 && {_x <= 57}) || (_x >= 65 && {_x <= 90}) ) then {
        _cleanChars pushBack _x;
    };
} forEach _projectileChars;

private _projectileTag = toString _cleanChars;
if (_projectileTag isEqualTo "") then {
    _projectileTag = "AMMO";
};
if ((count _projectileTag) > 10) then {
    _projectileTag = _projectileTag select [0,10];
};

private _profileName = format [ "%1.%2.%3", round (_caliber * 10) / 10, _grains, _projectileTag ];
if ((count _profileName) > 20) then {
    _profileName = _profileName select [0,20];
};

private _weaponIndex = 0;
{
    if (_x isEqualTo _weapon) exitWith { _weaponIndex = _forEachIndex; };
} forEach [primaryWeapon _unit, secondaryWeapon _unit, handgunWeapon _unit];

private _boreHeightCm = _unit getVariable ["ace_scopes_boreHeight", 0];
private _boreHeightSource = "cached";

if (_boreHeightCm <= 0) then {
    if (!isNil "ace_scopes_fnc_getBoreHeight") then {
        _boreHeightCm = [_unit, _weaponIndex] call ace_scopes_fnc_getBoreHeight;
        _boreHeightSource = "computed";
    };
};

if (_boreHeightCm <= 0) then {
    _boreHeightCm = 3.81;
    _boreHeightSource = "default";
};

private _zeroRange = 100;
private _zeroTOF = _zeroRange / (_mvTable select 3 select 1);
private _zeroDropM = 0.5 * 9.80665 * _zeroTOF * _zeroTOF;
// SQF atan returns degrees already
private _scopeBaseAngle = atan (_zeroDropM / _zeroRange);

private _preset = [
    _profileName,
    _mvTable select 3 select 1,
    _zeroRange,
    _scopeBaseAngle,
    _airFriction,
    _boreHeightCm,
    0,
    2,
    10,
    120,
    0,
    0,
    _bulletMass,
    _caliber,
    _twistCm,
    _bc,
    _dragModel,
    _atmosphere,
    _mvTable,
    _c1Table,
    true
];

if (isNil "ace_atragmx_gunList") exitWith {
    systemChat "Open ATragMX once first";
};

private _idx = -1;
{
    if ((_x select 0) isEqualTo _profileName) exitWith {
        _idx = _forEachIndex;
    };
} forEach ace_atragmx_gunList;

if (_idx >= 0) then {
    ace_atragmx_gunList set [_idx,_preset];
} else {
    ace_atragmx_gunList pushBack _preset;
};

profileNamespace setVariable [ "ACE_ATragMX_gunList", ace_atragmx_gunList ];
saveProfileNamespace;

private _tempStatus = if (_hasTempData) then { "YES" } else { "NO" };
private _barrelStatus = if (_hasBarrelData) then { "YES" } else { "NO" };

systemChat format [
    "Added: %1 | MV15: %2 m/s | BC: %3 (%4) | Twist: %5 cm (%6) | Bore: %7 in (%8, %9) | Temp: %10 | Barrel: %11",
    _profileName,
    round (_mvTable select 3 select 1),
    round (_bc * 1000) / 1000,
    _bcSource,
    _twistCm,
    _twistSource,
    round ((_boreHeightCm / 2.54) * 100) / 100,
    _boreHeightCm,
    _boreHeightSource,
    _tempStatus,
    _barrelStatus
];
