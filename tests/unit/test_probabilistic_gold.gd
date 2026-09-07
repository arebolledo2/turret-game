extends GutTest

var EconomyServiceScript = load("res://scripts/autoload/economy_service.gd")
var economy_service

func before_each():
	TestHelpers.reset_all_services()
	economy_service = autofree(EconomyServiceScript.new())
	# Manually reset state
	economy_service.reset_state()

func test_probabilistic_scrap_exact():
	# Test 1.0 multiplier (Exact 100)
	economy_service.total_scrap = 0
	var added = economy_service.add_scrap_probabilistic(100, 1.0)
	assert_eq(added, 100, "1.0 multiplier should return base amount")
	assert_eq(economy_service.total_scrap, 100, "Total scrap should update correctly")

	# Test 2.0 multiplier (Exact 200)
	economy_service.total_scrap = 0
	added = economy_service.add_scrap_probabilistic(100, 2.0)
	assert_eq(added, 200, "2.0 multiplier should double base amount")

func test_probabilistic_scrap_fractional_average():
	# Test 1.5 multiplier on 1 scrap base (Average should be 1.5)
	# Run 1000 times to smooth out randomness
	economy_service.total_scrap = 0
	var runs = 1000
	var total_added = 0

	for i in range(runs):
		total_added += economy_service.add_scrap_probabilistic(1, 1.5)

	var average = float(total_added) / runs
	# Allow for some variance, but it should be close to 1.5
	# 1.5 * 1000 = 1500 total scrap
	assert_between(average, 1.4, 1.6, "Average return for 1.5 mult should be roughly 1.5")

	# Check counts - usually roughly 500 ones and 500 twos
	# But exact counts vary, so just checking the average is safer validation of the logic

func test_probabilistic_scrap_low_multiplier():
	# Test 1.2 multiplier on 1 scrap base (Average should be 1.2)
	# Should yield mostly 1s, occasional 2s
	economy_service.total_scrap = 0
	var runs = 1000
	var total_added = 0

	for i in range(runs):
		total_added += economy_service.add_scrap_probabilistic(1, 1.2)

	var average = float(total_added) / runs
	assert_between(average, 1.1, 1.3, "Average return for 1.2 mult should be roughly 1.2")
