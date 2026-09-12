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
    private _g1M = [0.00,0.50,0.60,0.70,0.80,0.90,0.95,1.00,1.05,1.10,1.20,1.30,1.40,1.50,1.60,1.80,2.00,2.20,2.50,3.00,3.50,4.00];
    private _g1C = [0.2630,0.2030,0.2030,0.2170,0.2550,0.3420,0.4080,0.4810,0.5430,0.5880,0.6390,0.6590,0.6630,0.6570,0.6470,0.6210,0.5930,0.5690,0.5400,0.5130,0.5040,0.5010];
    private _g7C = [0.1200,0.1190,0.1190,0.1200,0.1240,0.1460,0.2050,0.3800,0.4040,0.4010,0.3880,0.3730,0.3580,0.3440,0.3320,0.3120,0.2980,0.2860,0.2700,0.2420,0.2150,0.1940];
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
            while { _bi < (_n - 1) && {_v > (_bounds select _bi)} } do {
                _bi = _bi + 1;
            };
            _bc = _bcs select _bi;
        };
        // Leave _c1Table zeroed: ATragMX then simulates drag from the preset's
        // airFriction (game physics), matching what ACE AB actually does.
        // Filling a converted C1 table makes ATragMX use real-world G1 drag,
        // which diverges from the game badly at long range.
        _dragModel = 1;
        _bcSource = "G7 (C1 table zeroed, airFriction used)";
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
