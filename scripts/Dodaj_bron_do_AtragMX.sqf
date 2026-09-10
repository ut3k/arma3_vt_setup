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

    if (_x <= (_xArray select 0)) exitWith {
        _yArray select 0
    };

    if (_x >= (_xArray select (_count - 1))) exitWith {
        _yArray select (_count - 1)
    };

    private _i = 0;

    while {
        _i < (_count - 1) &&
        {_x > (_xArray select (_i + 1))}
    } do {
        _i = _i + 1;
    };

    private _x0 = _xArray select _i;
    private _x1 = _xArray select (_i + 1);
    private _y0 = _yArray select _i;
    private _y1 = _yArray select (_i + 1);

    _y0 + (_y1 - _y0) * ((_x - _x0) / ((_x1 - _x0) max 0.0001))
};

private _initSpeed = getNumber (_magCfg >> "initSpeed");

if (_initSpeed <= 0) then {
    _initSpeed = getNumber (_ammoCfg >> "initSpeed");
};

private _weaponInitSpeed = getNumber (_weaponCfg >> "initSpeed");

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

if (_weaponBarrelLength <= 0) then {
    _weaponBarrelLength = 400;
};

private _hasBarrelData =
    (count _barrelLengths > 0) &&
    ((count _barrelLengths) isEqualTo (count _muzzleVelocities));

if (_hasBarrelData) then {
    _baseMV = [
        _weaponBarrelLength,
        _barrelLengths,
        _muzzleVelocities
    ] call _fnc_interpolate;
};

private _tempShifts = getArray (
    _ammoCfg >> "ACE_ammoTempMuzzleVelocityShifts"
);

private _hasTempData = (count _tempShifts) >= 11;

private _aceTemps = [
    -15, -10, -5, 0, 5, 10, 15, 20, 25, 30, 35
];

private _temps = [
    -15, 0, 10, 15, 25, 30, 35
];

private _mvTable = [];

{
    private _temperature = _x;
    private _shift = 0;

    if (_hasTempData) then {
        _shift = [
            _temperature,
            _aceTemps,
            _tempShifts
        ] call _fnc_interpolate;
    };

    _mvTable pushBack [
        _temperature,
        _baseMV + _shift
    ];
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

private _twist = getNumber (_weaponCfg >> "ACE_barrelTwist");

if (_twist <= 0) then {
    _twist = 254;
};

private _bcs = getArray (_ammoCfg >> "ACE_ballisticCoefficients");
private _bc = 0;

if ((count _bcs) > 0) then {
    _bc = _bcs select 0;
};

private _dragModel = getNumber (_ammoCfg >> "ACE_dragModel");

if (_dragModel <= 0) then {
    _dragModel = 1;
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
    if (
        (_x >= 48 && {_x <= 57}) ||
        (_x >= 65 && {_x <= 90})
    ) then {
        _cleanChars pushBack _x;
    };
} forEach _projectileChars;

private _projectileTag = toString _cleanChars;

if (_projectileTag isEqualTo "") then {
    _projectileTag = "AMMO";
};

if ((count _projectileTag) > 10) then {
    _projectileTag = _projectileTag select [0, 10];
};

private _profileName = format [
    "%1.%2.%3",
    round (_caliber * 10) / 10,
    _grains,
    _projectileTag
];

if ((count _profileName) > 20) then {
    _profileName = _profileName select [0, 20];
};

private _boreHeight = 3.81;

private _preset = [
    _profileName,
    _mvTable select 3 select 1,
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
    _caliber,
    _twist,
    _bc,
    _dragModel,
    _atmosphere,
    _mvTable,
    [
        [0,0],
        [0,0],
        [0,0],
        [0,0],
        [0,0],
        [0,0],
        [0,0]
    ],
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
    ace_atragmx_gunList set [_idx, _preset];
} else {
    ace_atragmx_gunList pushBack _preset;
};

profileNamespace setVariable [
    "ACE_ATragMX_gunList",
    ace_atragmx_gunList
];

saveProfileNamespace;

private _tempStatus = if (_hasTempData) then {
    "YES"
} else {
    "NO"
};

private _barrelStatus = if (_hasBarrelData) then {
    "YES"
} else {
    "NO"
};

systemChat format [
    "Added: %1 | MV15: %2 m/s | Barrel: %3 | Temp: %4",
    _profileName,
    round (_mvTable select 3 select 1),
    _barrelStatus,
    _tempStatus
];