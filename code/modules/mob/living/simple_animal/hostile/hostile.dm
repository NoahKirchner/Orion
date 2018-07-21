/mob/living/simple_animal/hostile
	faction = "hostile"
	var/stance = HOSTILE_STANCE_IDLE	//Used to determine behavior
	var/mob/living/target_mob
	var/attack_same = 0
	var/ranged = 0
	var/rapid = 0
	var/projectiletype
	var/projectilesound
	var/casingtype
	var/move_to_delay = 4 //delay for the automated movement.
	var/attack_delay = DEFAULT_ATTACK_COOLDOWN
	var/list/friends = list()
	var/break_stuff_probability = 10
	stop_automated_movement_when_pulled = 0
	var/destroy_surroundings = 1
	a_intent = I_HURT
	hunger_enabled = 0//Until automated eating mechanics are enabled, disable hunger for hostile mobs
	var/shuttletarget = null
	var/enroute = 0
	var/list/targets = list()
	var/attacked_times = 0

/mob/living/simple_animal/hostile/Destroy()
	friends = null
	target_mob = null
	targets = null
	return ..()

/mob/living/simple_animal/hostile/proc/FindTarget()

	if(!faction) //No faction, no reason to attack anybody.
		return null

	var/atom/T = null
	var/lowest_health = INFINITY // Max you can get
	stop_automated_movement = 0

	for(var/atom/A in targets)

		if(A == src)
			continue

		var/atom/F = Found(A)
		if(F)
			T = F
			break

		if(isliving(A))
			var/mob/living/L = A
			if((L.faction == src.faction) && !attack_same)
				continue
			if(L in friends)
				continue

			if(!L.stat && (L.health < lowest_health))
				lowest_health = L.health
				T = L
				break

		else if(istype(A, /obj/mecha)) // Our line of sight stuff was already done in ListTargets().
			var/obj/mecha/M = A
			if (M.occupant)
				T = M
				break

		if(istype(A, /obj/machinery/bot))
			var/obj/machinery/bot/B = A
			if (B.health > 0)
				T = B
				break

	if (T != target_mob)
		target_mob = T
		FoundTarget()
	if(!isnull(T))
		stance = HOSTILE_STANCE_ATTACK
	return T

/mob/living/simple_animal/hostile/bullet_act(var/obj/item/projectile/P, var/def_zone)
	..()
	if (ismob(P.firer) && target_mob != P.firer)
		target_mob = P.firer
		stance = HOSTILE_STANCE_ATTACK

/mob/living/simple_animal/hostile/attackby(var/obj/item/O, var/mob/user)
	..()
	if(target_mob != user)
		target_mob = user
		stance = HOSTILE_STANCE_ATTACK

mob/living/simple_animal/hostile/hitby(atom/movable/AM as mob|obj,var/speed = THROWFORCE_SPEED_DIVISOR)//Standardization and logging -Sieve
	..()
	if(istype(AM,/obj/))
		var/obj/O = AM
		if((target_mob != O.thrower) && ismob(O.thrower))
			target_mob = O.thrower
			stance = HOSTILE_STANCE_ATTACK

/mob/living/simple_animal/hostile/attack_generic(var/mob/user, var/damage, var/attack_message)
	..()
	if(target_mob != user)
		target_mob = user
		stance = HOSTILE_STANCE_ATTACK

/mob/living/simple_animal/hostile/attack_hand(mob/living/carbon/human/M as mob)
	..()
	if(target_mob != M)
		target_mob = M
		stance = HOSTILE_STANCE_ATTACK

//This proc is called after a target is acquired
/mob/living/simple_animal/hostile/proc/FoundTarget()
	return

/mob/living/simple_animal/hostile/proc/Found(var/atom/A)
	return

/mob/living/simple_animal/hostile/proc/MoveToTarget()
	stop_automated_movement = 1
	if(QDELETED(target_mob) || SA_attackable(target_mob))
		LoseTarget()
	if(target_mob in targets)
		if(ranged)
			if(get_dist(src, target_mob) <= 6)
				OpenFire(target_mob)
			else
				walk_to(src, target_mob, 1, move_to_delay)
		else
			stance = HOSTILE_STANCE_ATTACKING
			walk_to(src, target_mob, 1, move_to_delay)

/mob/living/simple_animal/hostile/proc/AttackTarget()

	stop_automated_movement = 1
	if(QDELETED(target_mob) || SA_attackable(target_mob))
		LoseTarget()
		return 0
	if(!(target_mob in targets))
		LoseTarget()
		return 0
	if(next_move >= world.time)
		return 0
	if(get_dist(src, target_mob) <= 1)	//Attacking
		AttackingTarget()
		attacked_times += 1
		return 1

/mob/living/simple_animal/hostile/proc/AttackingTarget()
	setClickCooldown(attack_delay)
	if(!Adjacent(target_mob))
		return
	if(isliving(target_mob))
		var/mob/living/L = target_mob
		L.attack_generic(src,rand(melee_damage_lower,melee_damage_upper),attacktext)
		return L
	if(istype(target_mob,/obj/mecha))
		var/obj/mecha/M = target_mob
		M.attack_generic(src,rand(melee_damage_lower,melee_damage_upper),attacktext)
		return M
	if(istype(target_mob,/obj/machinery/bot))
		var/obj/machinery/bot/B = target_mob
		B.attack_generic(src,rand(melee_damage_lower,melee_damage_upper),attacktext)
		return B

/mob/living/simple_animal/hostile/proc/LoseTarget()
	stance = HOSTILE_STANCE_IDLE
	target_mob = null
	walk(src, 0)
	LostTarget()

/mob/living/simple_animal/hostile/proc/LostTarget()
	return


/mob/living/simple_animal/hostile/proc/ListTargets(var/dist = 7)
	var/list/L = view(src, dist)

	for (var/obj/mecha/M in mechas_list)
		if (M.z == src.z && get_dist(src, M) <= dist)
			L += M

	return L

/mob/living/simple_animal/hostile/death()
	..()
	walk(src, 0)

/mob/living/simple_animal/hostile/think()
	..()
	switch(stance)
		if(HOSTILE_STANCE_IDLE)
			targets = ListTargets(10)
			target_mob = FindTarget()
			if(destroy_surroundings && isnull(target_mob))
				DestroySurroundings()

		if(HOSTILE_STANCE_ATTACK)
			if(destroy_surroundings)
				DestroySurroundings()
			MoveToTarget()

		if(HOSTILE_STANCE_ATTACKING)
			if(!AttackTarget() && destroy_surroundings)	//hit a window OR a mob, not both at once
				DestroySurroundings()
			if(attacked_times >= rand(0, 4))
				targets = ListTargets(10)
				target_mob = FindTarget()
				attacked_times = 0


/mob/living/simple_animal/hostile/proc/OpenFire(target_mob)
	var/target = target_mob
	visible_message("<span class='warning'> <b>[src]</b> fires at [target]!</span>")

	if(rapid)
		var/datum/callback/shoot_cb = CALLBACK(src, .proc/shoot_wrapper, target, loc, src)
		addtimer(shoot_cb, 1)
		addtimer(shoot_cb, 4)
		addtimer(shoot_cb, 6)

	else
		Shoot(target, src.loc, src)
		if(casingtype)
			new casingtype(loc)

	stance = HOSTILE_STANCE_IDLE
	target_mob = null
	return

/mob/living/simple_animal/hostile/proc/shoot_wrapper(target, location, user)
	Shoot(target, location, user)
	if (casingtype)
		new casingtype(loc)

/mob/living/simple_animal/hostile/proc/Shoot(var/target, var/start, var/user, var/bullet = 0)
	if(target == start)
		return

	var/obj/item/projectile/A = new projectiletype(user:loc)
	playsound(user, projectilesound, 100, 1)
	if(!A)	return
	var/def_zone = get_exposed_defense_zone(target)
	A.launch_projectile(target, def_zone)

/mob/living/simple_animal/hostile/proc/DestroySurroundings()
	if(prob(break_stuff_probability))
		for(var/dir in cardinal) // North, South, East, West
			for(var/obj/structure/window/obstacle in get_step(src, dir))
				if(obstacle.dir == reverse_dir[dir]) // So that windows get smashed in the right order
					obstacle.attack_generic(src,rand(melee_damage_lower,melee_damage_upper),attacktext)
					return 1
			var/obj/structure/obstacle = locate(/obj/structure, get_step(src, dir))
			if(istype(obstacle, /obj/structure/window) || istype(obstacle, /obj/structure/closet) || istype(obstacle, /obj/structure/table) || istype(obstacle, /obj/structure/grille))
				obstacle.attack_generic(src,rand(melee_damage_lower,melee_damage_upper),attacktext)
				return 1
	return 0

/mob/living/simple_animal/hostile/RangedAttack(atom/A, params) //Player firing
	if(ranged)
		setClickCooldown(attack_delay)
		target_mob = A
		OpenFire(A)
	..()


/mob/living/simple_animal/hostile/proc/check_horde()
	return 0
	if(emergency_shuttle.shuttle.location)
		if(!enroute && !target_mob)	//The shuttle docked, all monsters rush for the escape hallway
			if(!shuttletarget && escape_list.len) //Make sure we didn't already assign it a target, and that there are targets to pick
				shuttletarget = pick(escape_list) //Pick a shuttle target
			enroute = 1
			stop_automated_movement = 1
			spawn()
				if(!src.stat)
					horde()

		if(get_dist(src, shuttletarget) <= 2)		//The monster reached the escape hallway
			enroute = 0
			stop_automated_movement = 0

/mob/living/simple_animal/hostile/proc/horde()
	var/turf/T = get_step_to(src, shuttletarget)
	for(var/atom/A in T)
		if(istype(A,/obj/machinery/door/airlock))
			var/obj/machinery/door/airlock/D = A
			D.open(1)
		else if(istype(A,/obj/structure/simple_door))
			var/obj/structure/simple_door/D = A
			if(D.density)
				D.Open()
		else if(istype(A,/obj/structure/cult/pylon))
			A.attack_generic(src, rand(melee_damage_lower, melee_damage_upper))
		else if(istype(A, /obj/structure/window) || istype(A, /obj/structure/closet) || istype(A, /obj/structure/table) || istype(A, /obj/structure/grille))
			A.attack_generic(src, rand(melee_damage_lower, melee_damage_upper))
	Move(T)
	target_mob = FindTarget()
	if(!target_mob || enroute)
		spawn(10)
			if(!src.stat)
				horde()