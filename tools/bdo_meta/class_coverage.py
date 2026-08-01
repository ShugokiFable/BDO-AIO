#!/usr/bin/env python3
"""Shared class prefix / folder maps for best-effort all-class coverage."""

# heisha src README + pack inventory
FEMALE_CLASSES = {
    # prefix: (folder_id, display_name, native_3d_vagina_pac or None)
    "phw": ("2_phw", "Sorceress", "phw_00_nude_0001_noalpha.pac"),
    "pew": ("3_pew", "Ranger", "pew_00_nude_0001_noalpha.pac"),
    "pbw": ("5_pbw", "Tamer", "pbw_00_nude_0001.pac"),
    "pvw": ("7_pvw", "Valkyrie", "pvw_00_nude_0001.pac"),
    "pww": ("8_pww", "Witch", "pww_00_nude_0001.pac"),
    "pgw": ("11_pgw", "Guardian", None),  # reuse donor
    "pnw": ("13_pnw", "Kunoichi", "pnw_00_nude_0001.pac"),
    # Shai 14_plw intentionally skipped for nude/genital by Midnight policy
    "pdw": ("15_pdw", "Dark Knight", "pdw_00_nude_0001.pac"),
    "pcw": ("16_pcw", "Mystic", "pcw_00_nude_0001.pac"),
    "psw": ("17_psw", "Lahn", "psw_00_nude_0001.pac"),
    "ppw": ("21_ppw", "Nova", None),
    "pkww": ("22_pkww", "Maehwa", "pkww_00_nude_0002.pac"),
    "pfw": ("24_pfw", "Corsair", None),
    "pqw": ("25_pqw", "Drakania", None),
    "pkow": ("27_pkow", "Maegu", None),
    "pmyf": ("28_pmyf", "Woosa", None),
    "pnyw": ("29_pnyw", "Scholar", None),
    "pwge": ("32_pwge", "Deadeye", None),
    "pdkl": ("33_pdkl", "Seraph", None),
}

# Females with no Resorepless 3D-vagina PAC (Midnight/TGS body exists; genitals = EXPERIMENTAL-REUSE)
NEW_FEMALE_PREFIXES = tuple(
    p for p, v in FEMALE_CLASSES.items() if v[2] is None
)

# Preferred genital mesh donor per new female (best-effort body match; not artist-authored)
NEW_FEMALE_GENITAL_DONOR = {
    "pgw": "phw",   # Guardian -> Sorceress
    "ppw": "pww",   # Nova -> Witch
    "pfw": "psw",   # Corsair -> Lahn
    "pqw": "pdw",   # Drakania -> Dark Knight
    "pkow": "pnw",  # Maegu -> Kunoichi
    "pmyf": "pww",  # Woosa -> Witch
    "pnyw": "pww",  # Scholar -> Witch
    "pwge": "pew",  # Deadeye -> Ranger
    "pdkl": "psw",  # Seraph -> Lahn
}

# Preferred nude DDS stem (from Midnight Suzu textures) used to synthesize pubic hair
# for classes that have no class-named base DDS in the pack.
NEW_FEMALE_PUBIC_BASE = {
    "pgw": "phw_01_nude_0001",
    "ppw": "pww_01_nude_0001",
    "pfw": "pfw_01_nude_0001",  # own texture in pack; bin may not match size
    "pqw": "pdw_00_nude_0001",
    "pkow": "pdw_00_nude_0001",
    "pmyf": "pww_01_nude_0001",
    "pnyw": "pww_01_nude_0001",
    "pwge": "pew_01_nude_0001",
    "pdkl": "phw_01_nude_0001",  # Seraph — no class DDS; large-atlas donor
}

MALE_CLASSES = {
    # prefix: (folder_id, display_name, native_penis_pac base name)
    "phm": ("1_phm", "Warrior", "phm_00_nude_0001.pac"),
    "pgm": ("4_pgm", "Berserker", "pgm_00_nude_0001.pac"),
    "pkm": ("6_pkm", "Musa", "pkm_00_nude_0001.pac"),
    "pwm": ("8_pwm", "Wizard", "pwm_00_nude_0001.pac"),
    "pwmm": ("8_pwm", "Wizard revamp", "pwm_00_nude_0001.pac"),  # reuse wizard
    "pem": ("9_pem", "Archer", None),  # reuse warrior
    "pnm": ("13_pnm", "Ninja", "pnm_00_nude_0001.pac"),
    "pcm": ("16_pcm", "Striker", "pcm_00_nude_0001.pac"),
    "pam": ("18_pam", "Hashashin", None),  # reuse warrior
    "ppm": ("23_ppm", "Sage", None),  # reuse wizard
    # Wukong / Agent — unknown prefixes; will try live meta discovery if passed
}

# Preferred donor for missing female 3D vagina mesh (fallback order)
FEMALE_DONOR_ORDER = ["pww", "pdw", "pbw", "phw", "pvw", "pnw", "pcw", "psw", "pew"]

# Preferred donor for missing male penis mesh
MALE_DONOR_ORDER = ["phm", "pcm", "pwm", "pgm", "pkm", "pnm"]

# Pubic hair bin donors by DDS size buckets (bin was authored against these sizes)
# pbw/pdw classic 11MB; pew/phw/pww large variants differ — match by file size
PUBIC_BIN_NAMES = [
    "pbw_00_nude_0001.bin",
    "pdw_00_nude_0001.bin",
    "pew_01_nude_0001.bin",
    "phw_01_nude_0001.bin",
    "pww_01_nude_0001.bin",
]


def female_folder(prefix: str) -> str:
    return f"character/model/1_pc/{FEMALE_CLASSES[prefix][0]}/nude"


def male_folder(prefix: str) -> str:
    return f"character/model/1_pc/{MALE_CLASSES[prefix][0]}/nude"


def is_new_female(prefix: str) -> bool:
    return prefix in NEW_FEMALE_PREFIXES


def preferred_female_genital_donor(prefix: str) -> str | None:
    return NEW_FEMALE_GENITAL_DONOR.get(prefix)


def preferred_female_pubic_base(prefix: str) -> str | None:
    return NEW_FEMALE_PUBIC_BASE.get(prefix)
