"""Contract and target-independent checks shared by verify and demo."""
REQUIRED=set("id tier category source_ref chip_profile core_ratio compile_argv entry_functions expected_verdict oracle_note".split())
def validate(case,path):
    missing=REQUIRED-set(case)
    if missing:
        raise ValueError(f"{path}: missing {sorted(missing)}")
    if case["tier"] not in ("L1","L2","L3") or case["tier"] not in path.parts:
        raise ValueError(f"{path}: invalid tier")
    ratio=case["core_ratio"]
    if ratio not in (None,"0:1","1:0","1:1","1:2"):
        raise ValueError(f"{path}: invalid core ratio")
    if "execution" in case:
        e=case["execution"]
        kinds=e.get("kinds",["AIV"]*len(e["streams"]))
        if len(kinds)!=len(e["streams"]) or ratio!=f"{kinds.count('AIC')}:{kinds.count('AIV')}":
            raise ValueError(f"{path}: launch and ratio disagree")
        if set(e["streams"])!=set(case["entry_functions"]):
            raise ValueError(f"{path}: executable entry mismatch")
