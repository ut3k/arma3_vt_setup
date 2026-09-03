private _unit = player;

private _weapon = currentWeapon _unit;
if (_weapon isEqualTo "") exitWith {
    hint "Nie trzymasz żadnej broni.";
};

private _mag = currentMagazine _unit;
if (_mag isEqualTo "") exitWith {
    hint "Broń nie ma załadowanego magazynka.";
};

private _ammo = getText (configFile >> "CfgMagazines" >> _mag >> "ammo");
if (_ammo isEqualTo "") exitWith {
    hint "Nie udało się ustalić klasy amunicji.";
};

private _ammoCfg = configFile >> "CfgAmmo" >> _ammo;
private _weaponCfg = configFile >> "CfgWeapons" >> _weapon;

private _weaponName = getText (_weaponCfg >> "displayName");
private _magName = getText (configFile >> "CfgMagazines" >> _mag >> "displayName");

private _mass = getNumber (_ammoCfg >> "ACE_bulletMass");
private _diameter = getNumber (_ammoCfg >> "ACE_caliber");
private _airFriction = getNumber (_ammoCfg >> "airFriction");
private _dragModel = getNumber (_ammoCfg >> "ACE_dragModel");
private _atmosphere = getText (_ammoCfg >> "ACE_standardAtmosphere");

private _bcArray = getArray (_ammoCfg >> "ACE_ballisticCoefficients");
private _bc = if ((count _bcArray) > 0) then {
    _bcArray select 0
} else {
    0
};

private _mvArray = getArray (_ammoCfg >> "ACE_muzzleVelocities");

private _mv = if ((count _mvArray) > 0) then {
    _mvArray select ((count _mvArray) - 1)
} else {
    getNumber (configFile >> "CfgMagazines" >> _mag >> "initSpeed")
};

private _twist = getNumber (_weaponCfg >> "ACE_barrelTwist");

if (_twist <= 0) then {
    _twist = 25.4;
};

private _profileName = format [
    "%1 / %2",
    _weaponName,
    _magName
];

private _profile = [
    _profileName,        // 0 Name
    _mv,                 // 1 Muzzle Velocity
    100,                 // 2 Zero Range
    0,                   // 3 Scope Base Angle
    _airFriction,        // 4 Air Friction
    7.62,                // 5 Bore Height
    0,                   // 6 Scope Unit
    2,                   // 7 Click Unit
    10,                  // 8 Click Number
    120,                 // 9 Maximum Elevation
    0,                   // 10 Dialed Elevation
    0,                   // 11 Dialed Windage
    _mass,                // 12 Bullet Mass
    _diameter,            // 13 Bullet Diameter
    _twist,               // 14 Rifle Twist
    _bc,                  // 15 Ballistic Coefficient
    _dragModel,           // 16 Drag Model
    _atmosphere,          // 17 Atmosphere
    [
        [-15,_mv],
        [0,_mv],
        [10,_mv],
        [15,_mv],
        [25,_mv],
        [30,_mv],
        [35,_mv]
    ],                    // 18 MV/Temp
    [
        [0,_bc],
        [0,_bc],
        [0,_bc],
        [0,_bc],
        [0,_bc],
        [0,_bc],
        [0,_bc]
    ],                    // 19 BC/Distance
    true                  // 20 Persistent
];

if (isNil "ace_atragmx_gunList") then {
    [] call ace_atragmx_fnc_initGunList;
};

ace_atragmx_gunList pushBack _profile;

profileNamespace setVariable [
    "ACE_ATragMX_gunList",
    ace_atragmx_gunList
];

saveProfileNamespace;

hint format [
    "Dodano do ATragMX:\n%1\n\nAmmo: %2\nMV: %3 m/s\nBC: %4\nDrag: G%5",
    _profileName,
    _ammo,
    round _mv,
    _bc,
    _dragModel
];
