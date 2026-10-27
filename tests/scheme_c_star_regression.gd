extends "res://tests/star_runner.gd"
const GenderEvidence=preload("res://tests/scheme_c_gender_evidence.gd")
var scheme_c_evidence: RefCounted

func run() -> void:
	scheme_c_evidence=GenderEvidence.new("star")
	scheme_c_evidence.started=Appearance.set_player_gender("female")
	await super.run()
	finish_gender_evidence()

func check(condition: bool, description: String) -> void:
	super.check(condition,description)
	if is_instance_valid(scheme_c_evidence): scheme_c_evidence.observe(self,condition,description)

func finish_gender_evidence() -> void:
	var original_checks: int=checked;var original_failures: int=failed
	for proof in scheme_c_evidence.validations(["memories","trials","postlife","letter_519","letter_520","letter_521"]):
		super.check(bool(proof.ok),str(proof.text))
	scheme_c_evidence.write_evidence(original_checks,original_failures,checked-original_checks,failed-original_failures)
	print("SCHEME C FEMALE STAR EVIDENCE RESULT: %d checks, %d failures" % [checked-original_checks,failed-original_failures])
	get_tree().quit(1 if failed else 0)
