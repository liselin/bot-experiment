--require(GetScriptDirectory() ..  "/ability_item_usage_generic")
local ability_item_usage_generic = dofile( GetScriptDirectory().."/ability_item_usage_generic" )
local utils = require(GetScriptDirectory() ..  "/util")
--local inspect = require(GetScriptDirectory() ..  "/inspect")
--local enemyStatus = require(GetScriptDirectory() .. "/enemy_status" )

function AbilityLevelUpThink()  
	ability_item_usage_generic.AbilityLevelUpThink(); 
end
function BuybackUsageThink()
	ability_item_usage_generic.BuybackUsageThink();
end
function CourierUsageThink()
	ability_item_usage_generic.CourierUsageThink();
end

local castDCDesire = 0;
local castSPDesire = 0;
local castSPIDesire = 0;
local castSPODesire = 0;
local castOCDesire = 0;
local castRCDesire = 0;
local moveDesire = 0;

function AbilityUsageThink()

	local npcBot = GetBot();
	
	-- Check if we're already using an ability
	if ( npcBot:IsUsingAbility() or npcBot:IsChanneling() or npcBot:IsSilenced() ) then return end

	abilityDC = npcBot:GetAbilityByName( "wisp_tether" );
	abilitySP = npcBot:GetAbilityByName( "wisp_spirits" );
	abilitySPI = npcBot:GetAbilityByName( "wisp_spirits_in" );
	abilitySPO = npcBot:GetAbilityByName( "wisp_spirits_out" );
	abilityOC = npcBot:GetAbilityByName( "wisp_overcharge" );
	abilityRC = npcBot:GetAbilityByName( "wisp_relocate" );

	-- Consider using each ability
	castDCDesire, castDCTarget = ConsiderDeathCoil();
	castSPDesire = ConsiderSpirits();
	castSPIDesire = ConsiderSpiritsIn();
	castSPODesire = ConsiderSpiritsOut();
	castOCDesire = ConsiderOverCharge();
	castRCDesire, castRCLocation = ConsiderRelocate();
	moveDesire, moveLocation = ConsiderMoving()

	if ( castRCDesire > 0 ) 
	then
	--print("useRC")
		npcBot:Action_UseAbilityOnLocation( abilityRC, castRCLocation );
		return;
	end
	
	if ( castDCDesire > 0 ) 
	then
	--print("useDC")
		npcBot:Action_UseAbilityOnEntity( abilityDC, castDCTarget );
		return;
	end
	
	if ( castOCDesire > 0 ) 
	then
	--print("useOC")
		npcBot:Action_UseAbility( abilityOC );
		return;
	end
	
	if ( castSPDesire > 0 ) 
	then
		--print("useSP")
		npcBot:Action_UseAbility( abilitySP );
		return;
	end
	
	if ( castSPIDesire > 0 ) 
	then
	--print("useSPI")
		npcBot:Action_UseAbility( abilitySPI );
		return;
	end
	
	if ( castSPODesire > 0 ) 
	then
	--print("useSPO")
		npcBot:Action_UseAbility( abilitySPO );
		return;
	end
	if moveDesire > 0 
	then
		npcBot:Action_MoveToLocation( moveLocation );
		return;
	end
	
	
end


function CanCastDeathCoilOnTarget( npcTarget )
	return npcTarget:CanBeSeen() and not npcTarget:IsMagicImmune() and not npcTarget:IsInvulnerable();
end

function isDisabled(npcTarget)
	if npcTarget:IsRooted( ) or npcTarget:IsStunned( ) or npcTarget:IsHexed( ) or npcTarget:IsSilenced( )  then
		return true;
	end
	return false;
end

function ConsiderDeathCoil()

	local npcBot = GetBot();

	-- Make sure it's castable
	if ( not abilityDC:IsFullyCastable() or abilityDC:IsHidden() or npcBot:HasModifier("modifier_wisp_tether") ) then 
		return BOT_ACTION_DESIRE_NONE, 0;
	end
	
	if castRCDesire > 0 then
		return BOT_ACTION_DESIRE_NONE, 0;
	end

	-- Get some of its values
	local nCastRange = abilityDC:GetCastRange();
	
	local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( 1000, true, BOT_MODE_NONE );
	
	-- If we're seriously retreating, see if we can suicide
	if ( npcBot:GetActiveMode() == BOT_MODE_RETREAT and npcBot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and
		tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes > 0 
		) 
	then
		local numPlayer =  GetTeamPlayers(GetTeam());
		local maxDist = 0;
		local target = nil;
		for i = 1, #numPlayer
		do
			local dist = GetUnitToUnitDistance(GetTeamMember(i), npcBot);
			if dist > maxDist and dist < nCastRange and GetTeamMember(i):IsAlive() then
				maxDist = dist;
				target = GetTeamMember(i);
			end
		end
		if target ~= nil then
			return BOT_ACTION_DESIRE_MODERATE, target;
		end
		local tableNearbyCreeps = npcBot:GetNearbyLaneCreeps( 1000, false );
		for _,creep in pairs(tableNearbyCreeps)
		do
			local dist = GetUnitToUnitDistance(creep, npcBot);
			if dist > maxDist and dist < nCastRange then
				maxDist = dist;
				target = creep;
			end
		end
		if target ~= nil then
			return BOT_ACTION_DESIRE_MODERATE, target;
		end
	end

	-- If we're in a teamfight, use it on the protect ally
	local tableNearbyAttackingAlliedHeroes = npcBot:GetNearbyHeroes( 1000, false, BOT_MODE_ATTACK );
	if ( #tableNearbyAttackingAlliedHeroes >= 2 ) 
	then
		local lowHpAlly = nil;
		local nLowestHealth = 1000;

		local tableNearbyAllies = npcBot:GetNearbyHeroes( 1000, false, BOT_MODE_NONE  );
		for _,npcAlly in pairs( tableNearbyAllies )
		do
			if ( CanCastDeathCoilOnTarget( npcAlly ) )
			then
				local nAllyHP = npcAlly:GetHealth();
				if ( ( nAllyHP < nLowestHealth and npcAlly:GetHealth() / npcAlly:GetMaxHealth() < 0.5 ) or isDisabled(npcAlly) )
				then
					nLowestHealth = nAllyHP;
					lowHpAlly = npcAlly;
				end
			end
		end
		if ( lowHpAlly ~= nil )
		then
			return BOT_ACTION_DESIRE_MODERATE, lowHpAlly;
		end
	end

	-- If we're going after someone
	if ( npcBot:GetActiveMode() == BOT_MODE_ATTACK or
		 npcBot:GetActiveMode() == BOT_MODE_DEFEND_ALLY ) 
	then
		local npcTarget = npcBot:GetTarget();
		if ( npcTarget ~= nil and GetUnitToUnitDistance( npcTarget, npcBot ) < 1000 ) 
		then
			local numPlayer =  GetTeamPlayers(GetTeam());
			local minDist = 10000;
			local target = nil;
			for i = 1, #numPlayer
			do
				local dist = GetUnitToUnitDistance(GetTeamMember(i), npcTarget);
				if dist < minDist and dist < nCastRange and GetTeamMember(i):IsAlive() then
					minDist = dist;
					target = GetTeamMember(i);
				end
			end
			if target ~= nil then
				return BOT_ACTION_DESIRE_MODERATE, target;
			end
		end
	end
	
	if npcBot:GetActiveMode() == BOT_MODE_ROAM or
	   npcBot:GetActiveMode() == BOT_MODE_TEAM_ROAM or
	   npcBot:GetActiveMode() == BOT_MODE_GANK 
	then
		local npcTarget = npcBot:GetTarget();
		if ( npcTarget ~= nil and GetUnitToUnitDistance( npcTarget, npcBot ) > 5000 ) 
		then
			local tableNearbyAllies = npcBot:GetNearbyHeroes( 1000, false, BOT_MODE_NONE  );
			if tableNearbyAllies ~= nil and #tableNearbyAllies >= 1 and abilityRC:IsFullyCastable() then
				return BOT_ACTION_DESIRE_MODERATE, tableNearbyAllies[1];
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, 0;

end

function ConsiderSpirits()
	local npcBot = GetBot();

	-- Make sure it's castable
	if ( not abilitySP:IsFullyCastable() ) then 
		return BOT_ACTION_DESIRE_NONE;
	end
	local nMaxRange = abilitySP:GetSpecialValueInt("max_range");
	--[[if npcBot:DistanceFromFountain() > 1000 then
		return BOT_ACTION_DESIRE_MODERATE
	end]]--
	
	if ( npcBot:GetActiveMode() == BOT_MODE_ROAM or
		 npcBot:GetActiveMode() == BOT_MODE_TEAM_ROAM or
		 npcBot:GetActiveMode() == BOT_MODE_GANK or
		 npcBot:GetActiveMode() == BOT_MODE_ATTACK or
		 npcBot:GetActiveMode() == BOT_MODE_DEFEND_ALLY ) 
	then
		local npcTarget = npcBot:GetTarget();
		if ( npcTarget ~= nil and GetUnitToUnitDistance( npcTarget, npcBot ) < nMaxRange ) 
		then
			return BOT_ACTION_DESIRE_MODERATE
		end
	end

	return BOT_ACTION_DESIRE_NONE;
end

function ConsiderSpiritsIn()
	local npcBot = GetBot();
	-- Make sure it's castable
	if ( not abilitySPI:IsFullyCastable() or abilitySPI:IsHidden() or not npcBot:HasModifier("modifier_wisp_spirits") ) then 
		return BOT_ACTION_DESIRE_NONE;
	end
	
	local nMinRange = abilitySP:GetSpecialValueInt("min_range");
	local nMaxRange = abilitySP:GetSpecialValueInt("max_range");
	local nRadius = abilitySP:GetSpecialValueInt("radius");
	
	if ( npcBot:GetActiveMode() == BOT_MODE_ROAM or
		 npcBot:GetActiveMode() == BOT_MODE_TEAM_ROAM or
		 npcBot:GetActiveMode() == BOT_MODE_GANK or
		 npcBot:GetActiveMode() == BOT_MODE_ATTACK or
		 npcBot:GetActiveMode() == BOT_MODE_DEFEND_ALLY ) 
	then
		local npcTarget = npcBot:GetTarget();
		if ( npcTarget ~= nil and GetUnitToUnitDistance( npcTarget, npcBot ) < nMaxRange /2 )
		then
			if not abilitySPI:GetToggleState() then
				return BOT_ACTION_DESIRE_MODERATE
			end
		end
	end
	
	--[[if npcBot:DistanceFromFountain() > 2000 and npcBot:DistanceFromFountain() < 3000   then
		if not abilitySPI:GetToggleState() then
			return BOT_ACTION_DESIRE_MODERATE
		end
	end]]--
	
	return BOT_ACTION_DESIRE_NONE;
end

function ConsiderSpiritsOut()
	local npcBot = GetBot();
	
	-- Make sure it's castable
	if ( not abilitySPO:IsFullyCastable() or abilitySPO:IsHidden() or not npcBot:HasModifier("modifier_wisp_spirits") ) then 
		return BOT_ACTION_DESIRE_NONE;
	end

	local nMinRange = abilitySP:GetSpecialValueInt("min_range");
	local nMaxRange = abilitySP:GetSpecialValueInt("max_range");
	local nRadius = abilitySP:GetSpecialValueInt("radius");
	
	if ( npcBot:GetActiveMode() == BOT_MODE_ROAM or
		 npcBot:GetActiveMode() == BOT_MODE_TEAM_ROAM or
		 npcBot:GetActiveMode() == BOT_MODE_GANK or
		 npcBot:GetActiveMode() == BOT_MODE_ATTACK or
		 npcBot:GetActiveMode() == BOT_MODE_DEFEND_ALLY ) 
	then
		local npcTarget = npcBot:GetTarget();
		if ( npcTarget ~= nil and GetUnitToUnitDistance( npcTarget, npcBot ) >= nMaxRange/2  ) 
		then
			if not abilitySPO:GetToggleState() then
				return BOT_ACTION_DESIRE_MODERATE
			end
		end
	end
	
	--[[if ( npcBot:DistanceFromFountain() >= 3000 and npcBot:DistanceFromFountain() < 4000 ) or npcBot:DistanceFromFountain() > 5000 then
		if not abilitySPO:GetToggleState() then
			return BOT_ACTION_DESIRE_MODERATE
		end
	end]]--
	
	return BOT_ACTION_DESIRE_NONE;
end

function ConsiderOverCharge()
	local npcBot = GetBot();
	-- Make sure it's castable
	if ( not abilityOC:IsFullyCastable() ) then 
		return BOT_ACTION_DESIRE_NONE;
	end
	
	local tetheredAlly = nil; 
	
	local NearbyAttackingAllies = npcBot:GetNearbyHeroes( 1000, false, BOT_MODE_ATTACK );
	for _,ally in pairs(NearbyAttackingAllies)
	do
		if ally:GetActiveMode() == BOT_MODE_ATTACK and ally:HasModifier('modifier_wisp_tether') then
			tetheredAlly = ally
		end
	end
	
	if npcBot:GetActiveMode() == BOT_MODE_ATTACK and tetheredAlly ~= nil then
		local npcTarget = npcBot:GetTarget();
		local allyAttackRange = tetheredAlly:GetAttackRange();
		local nAttackRange = npcBot:GetAttackRange();
		if npcTarget ~= nil and npcTarget:IsHero() and 
			( GetUnitToUnitDistance(npcTarget ,tetheredAlly) <= allyAttackRange or  GetUnitToUnitDistance(npcTarget ,npcBot) <= nAttackRange )
		then
			if  npcBot:HasModifier('modifier_wisp_tether') and npcBot:GetHealth()/npcBot:GetMaxHealth() > .3 and npcBot:GetMana()/npcBot:GetMaxMana() > .15 then
				if not abilityOC:GetToggleState() then
					return BOT_ACTION_DESIRE_MODERATE
				end
			else
				if abilityOC:GetToggleState() then
					return BOT_ACTION_DESIRE_MODERATE
				end
			end
		else
			if abilityOC:GetToggleState() then
				return BOT_ACTION_DESIRE_MODERATE
			end
		end	
	else
		if abilityOC:GetToggleState() then
			return BOT_ACTION_DESIRE_MODERATE
		end
	end
	
	return BOT_ACTION_DESIRE_NONE;
end

function ConsiderRelocate()
	local npcBot = GetBot();
	-- Make sure it's castable
	if ( not abilityRC:IsFullyCastable() ) then 
		return BOT_ACTION_DESIRE_NONE;
	end
	
	local RB = Vector(-7200,-6666)
	local DB = Vector(7137,6548)
	
	-- If we're seriously retreating, see if we can land a stun on someone who's damaged us recently
	if ( npcBot:GetActiveMode() == BOT_MODE_RETREAT and npcBot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH ) 
	then
		local tableNearbyEnemyHeroes = npcBot:GetNearbyHeroes( 1000, true, BOT_MODE_NONE );
		if tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes > 1 and npcBot:WasRecentlyDamagedByAnyHero(1.0) then
			if GetTeam( ) == TEAM_DIRE then
				return BOT_ACTION_DESIRE_MODERATE, DB;
			end
			if GetTeam( ) == TEAM_RADIANT then
				return BOT_ACTION_DESIRE_MODERATE, RB;
			end
		end
	end
	
	local tableNearbyAttackingAlliedHeroes = npcBot:GetNearbyHeroes( 1000, false, BOT_MODE_ATTACK );
	if ( #tableNearbyAttackingAlliedHeroes >= 2 ) 
	then
		local lowHpAlly = nil;
		local nLowestHealth = 1000;

		local tableNearbyAllies = npcBot:GetNearbyHeroes( 1000, false, BOT_MODE_NONE  );
		for _,npcAlly in pairs( tableNearbyAllies )
		do
			if ( CanCastDeathCoilOnTarget( npcAlly ) )
			then
				local nAllyHP = npcAlly:GetHealth();
				if ( ( nAllyHP < nLowestHealth and npcAlly:GetHealth() / npcAlly:GetMaxHealth() < 0.35 ) or isDisabled(npcAlly) )
				then
					nLowestHealth = nAllyHP;
					lowHpAlly = npcAlly;
				end
			end
		end
		if ( lowHpAlly ~= nil and abilityDC:IsFullyCastable() )
		then
			if GetTeam( ) == TEAM_DIRE then
				return BOT_ACTION_DESIRE_MODERATE, DB;
			end
			if GetTeam( ) == TEAM_RADIANT then
				return BOT_ACTION_DESIRE_MODERATE, RB;
			end
		end
	end

	if ( npcBot:GetActiveMode() == BOT_MODE_ROAM or
		 npcBot:GetActiveMode() == BOT_MODE_TEAM_ROAM or
		 npcBot:GetActiveMode() == BOT_MODE_GANK  ) 
	then
		local npcTarget = npcBot:GetTarget();
		if ( npcTarget ~= nil and GetUnitToUnitDistance( npcTarget, npcBot ) > 3000  ) 
		then
			local tableNearbyAllies = npcBot:GetNearbyHeroes( 800, false, BOT_MODE_NONE  );
			if tableNearbyAllies ~= nil and #tableNearbyAllies >= 1 and abilityDC:IsFullyCastable() then
				return BOT_ACTION_DESIRE_MODERATE, npcTarget:GetLocation();
			end
		end
	end
	
	return BOT_ACTION_DESIRE_NONE, 0; 
end

function ConsiderMoving()
	local npcBot = GetBot();
	if DotaTime() < 0 and npcBot:DistanceFromFountain() < 1000 then
			return BOT_ACTION_DESIRE_HIGH, GetTower( GetTeam(), TOWER_MID_3 ):GetLocation() + RandomVector(200);
		--[[if GetTeam() == TEAM_RADIANT then
			return BOT_ACTION_DESIRE_ABSOLUTE, GetTower( GetTeam(), TOWER_BOT_1 ):GetLocation() + RandomVector(200);	
		elseif 	GetTeam() == TEAM_DIRE then
			return BOT_ACTION_DESIRE_ABSOLUTE, GetTower( GetTeam(), TOWER_TOP_1  ):GetLocation() + RandomVector(200);	
		end]]--
	end
	return BOT_ACTION_DESIRE_NONE, 0; 
end