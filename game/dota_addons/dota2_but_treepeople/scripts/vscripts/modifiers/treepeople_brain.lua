
local XPTable = nil
local maxLevel = nil

treepeople_brain = class({})

local treepeople_data = Treepeople_data

function treepeople_brain:RemoveOnDeath() return true end
function treepeople_brain:IsPurgable() return false end
function treepeople_brain:IsPurgeException() return false end
function treepeople_brain:IsHidden() return true end 	-- we can hide the modifier

function treepeople_brain:GetAttributes()
	return 
		  MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE -- Allows modifier to be assigned to invulnerable entities. 
end

local MODE = 
{
	PATROL = 1,
	TAKE_POS = 2,
	ATTACK = 3,
}

function treepeople_brain:MoveTo( vPos, bQueue )
	ExecuteOrderFromTable({
		UnitIndex = self:GetParent():entindex(),
		OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION,
		Position = vPos,
		Queue = bQueue,
	})
end

function treepeople_brain:Attack()
	if self:IsValidTarget() then
		if self.chase_target:GetClassname() ~= "npc_dota_watch_tower" then
			AddFOWViewer( self:GetParent():GetTeamNumber(), self.chase_target:GetAbsOrigin(), 350, 0.5, true )
			
			ExecuteOrderFromTable({
				UnitIndex = self:GetParent():entindex(),
				OrderType = DOTA_UNIT_ORDER_ATTACK_TARGET,
				TargetIndex = self.chase_target:entindex(),
				Queue = false,
			})
		elseif not self:GetParent():IsChanneling() then
			self:TryCapture()
		end
	end
end

local function GetRandomTree( pos, range )
	local hTree = nil
	local tree_table = GridNav:GetAllTreesAroundPoint( pos, range, false )
	local list = {}
	for k, v in pairs(tree_table) do
		if ( v.IsStanding == nil ) or v:IsStanding() then
			list[#list + 1] = v
		end
	end
	
	if #list > 0 then
		return list[ RandomInt( 1, #list ) ]
	end
	
	return nil
end

local function GetClosestTree( pos, targetPos, range )
	local hTree = nil
	local tree_table = GridNav:GetAllTreesAroundPoint( pos, range, false )
	local closest = nil
	local dist = 20000
	
	for k, v in pairs(tree_table) do
		if ( v.IsStanding == nil ) or v:IsStanding() then
			local newDist = ( v:GetAbsOrigin() - targetPos ):Length2D()
			if ( closest == nil ) or ( newDist < dist ) then
				dist = newDist
				closest = v
			end
		end
	end
	
	return closest
end

function treepeople_brain:ChangeModeTo( newMode )
	local oldMode = self.mode
	self.mode = newMode
	local parent = self:GetParent()
	local pos = parent:GetAbsOrigin()
	
	if newMode == MODE.PATROL then
		-- DebugDrawCircle( pos, Vector( 0, 128, 255 ), 40, 90, true, 0.75 )
		if oldMode ~= MODE.PATROL then
			self.patrolTarget = nil
		end
			
		self:StartIntervalThink( 0.75 )
		
		-- reset flags
		self.chase_target = nil
		self.dont_call_bros = nil
		self.dont_attack_bros = nil
		
		if ( self.patrolTarget == nil ) or ( ( self.patrolTarget - pos ):Length2D() < 50 ) then
		
			-- look for tree we will PATROL to
			local hTree = GetRandomTree( pos, 1200 )
			
			if hTree ~= nil then
				self.patrolTarget = hTree:GetAbsOrigin()
			else
				self.patrolTarget = Vector( RandomFloat( GetWorldMinX(), GetWorldMaxX() ), RandomFloat( GetWorldMinY(), GetWorldMaxY() ), 0 )
				print( "get weird pos" )
			end
		end
		
		DebugDrawLine( pos, self.patrolTarget, 0, 128, 255, true, 0.75 )
 		DebugDrawCircle( self.patrolTarget, Vector( 0, 128, 255 ), 40, 40, true, 0.75 )

		self:MoveTo( self.patrolTarget, false )

	elseif newMode == MODE.TAKE_POS then
		-- first, find attack pos in trees closest to target
		self.dont_attack_bros = nil
		
		self:StartIntervalThink( 0.5 )
		
		if not self:IsValidTarget() then
			
			-- lost the target, keep patrolling
			self:ChangeModeTo( MODE.PATROL )
		else
					
			DebugDrawLine( pos, self.chase_target:GetAbsOrigin(), 0, 255, 0, true, 0.5 )
			
			if not self.dont_call_bros then
				self.dont_call_bros = true
				-- call bros
				local bros = self:FindBros( 1000, self.chase_target:GetAbsOrigin() )
				
				--print( tostring(#bros) .. " bros, i found the foe, help me!" )
				
				for u,unit in pairs(bros) do
					if unit ~= parent then
						local mod = unit:FindModifierByName("treepeople_brain")
						if ( mod ~= nil ) and ( mod.mode == MODE.PATROL ) then
							mod.chase_target = self.chase_target
							mod.dont_call_bros = true
							mod:ChangeModeTo( MODE.TAKE_POS )
						end
					end
				end
			end
			
			-- take better position
			local hTree = GetClosestTree( self.chase_target:GetAbsOrigin(), self:GetParent():GetAbsOrigin(), 400 )
			
			if hTree ~= nil then				
				DebugDrawCircle( hTree:GetAbsOrigin(), Vector( 240, 240, 10 ), 40, 40, true, 0.5 )
				self:MoveTo( hTree:GetAbsOrigin(), false )
			else
				-- lost the target, keep patrolling
				self:ChangeModeTo( MODE.PATROL )
			end
		end
	elseif newMode == MODE.ATTACK then
		self.dont_call_bros = nil
		
		self:StartIntervalThink( 0.4 )

		-- target has died or got captured
		if not self:IsValidTarget() or self.chase_target:GetTeamNumber() == self:GetParent():GetTeamNumber() then
			
			-- lost the target, keep patrolling
			print( "my attacking target got killed, go back to patrolling" )
			self:ChangeModeTo( MODE.PATROL )
		else
			DebugDrawLine( pos, self.chase_target:GetAbsOrigin(), 255, 0, 0, true, 0.4 )
			self:Attack()
		end
	end
	
end

function treepeople_brain:FindBros( range, pos )
	local parent = self:GetParent()
	
	local units = FindUnitsInRadius( 
		parent:GetTeamNumber(), 
		pos,
		parent,
		range,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY,
		DOTA_UNIT_TARGET_CREEP + DOTA_UNIT_TARGET_HERO,
		DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
		FIND_ANY_ORDER, 
		false )
		
	return units
end

function treepeople_brain:LookForEnemy( range )
	local parent = self:GetParent()
	
	local targets = DOTA_UNIT_TARGET_CREEP + DOTA_UNIT_TARGET_HERO
	
	if parent:GetLevel() > 3 then
		targets = DOTA_UNIT_TARGET_ALL
	end
	
	local units = FindUnitsInRadius( 
		parent:GetTeamNumber(), 
		parent:GetAbsOrigin(),
		parent,
		range,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		targets,
		DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_NO_INVIS + DOTA_UNIT_TARGET_FLAG_NOT_ATTACK_IMMUNE,
		FIND_CLOSEST, 
		false )

	local hitTarget = nil

	for u,unit in pairs(units) do
		hitTarget = unit
		break
	end
	
	return hitTarget
end

function treepeople_brain:IsValidTarget()
	return ( self.chase_target ~= nil ) and ( self.chase_target:IsAlive() )
end

function treepeople_brain:OnCreated( kv )
	if IsClient() then return end
	
	XPTable = XPTable or BUTTINGS.ALTERNATIVE_XP_TABLE()
	maxLevel = maxLevel or BUTTINGS.MAX_LEVEL
	self.xp = 0
	
	self.hHook = self:GetParent():FindAbilityByName( "pudge_meat_hook" )
	self.hHook:SetLevel( 1 )
	
	self.hTagTeam = self:GetParent():FindAbilityByName( "tusk_tag_team" )
	self.hTagTeam:SetLevel( 0 )
	
	self.hBoulder = self:GetParent():FindAbilityByName( "mud_golem_hurl_boulder" )
	self.hBoulder:SetLevel( 0 )
	
	self.hRush = self:GetParent():FindAbilityByName( "phantom_lancer_phantom_edge" )
	self.hRush:SetLevel( 0 )
	
	self.hCapture = self:GetParent():FindAbilityByName( "ability_capture" )
	self.hCapture:SetLevel( 1 )
	
	treepeople_data.count = treepeople_data.count + 1
	
	self:GetParent():SetShouldDoFlyHeightVisual( false )
	
	self:ChangeModeTo( MODE.PATROL )
end

function treepeople_brain:TryCapture()
	if self:IsValidTarget() and self.hCapture:IsFullyCastable() then
		AddFOWViewer( self:GetParent():GetTeamNumber(), self.chase_target:GetAbsOrigin(), 350, 0.5, true )
		
		ExecuteOrderFromTable({
			UnitIndex = self:GetParent():entindex(),
			OrderType = DOTA_UNIT_ORDER_CAST_TARGET,
			TargetIndex = self.chase_target:entindex(),
			AbilityIndex = self.hCapture:entindex(),
			Queue = false,
		})
	end
end

function treepeople_brain:TryCastHook()
	if self:IsValidTarget() and self.hHook:IsFullyCastable() then
		ExecuteOrderFromTable({
			UnitIndex = self:GetParent():entindex(),
			OrderType = DOTA_UNIT_ORDER_CAST_POSITION,
			Position  = self.chase_target:GetAbsOrigin(),
			AbilityIndex = self.hHook:entindex(),
			Queue = false,
		})
	end
end

function treepeople_brain:TryCastTagTeam()
	if self:IsValidTarget() and self.hTagTeam:IsFullyCastable() then
		ExecuteOrderFromTable({
			UnitIndex = self:GetParent():entindex(),
			OrderType = DOTA_UNIT_ORDER_CAST_NO_TARGET,
			AbilityIndex = self.hTagTeam:entindex(),
			Queue = false,
		})
	end
end

function treepeople_brain:TryCastBoulder()
	if self:IsValidTarget() and self.hBoulder:IsCooldownReady() and self.hBoulder:GetLevel() > 0 then
		AddFOWViewer( self:GetParent():GetTeamNumber(), self.chase_target:GetAbsOrigin(), 350, 0.5, true )
		
		ExecuteOrderFromTable({
			UnitIndex = self:GetParent():entindex(),
			OrderType = DOTA_UNIT_ORDER_CAST_TARGET,
			TargetIndex = self.chase_target:entindex(),
			AbilityIndex = self.hBoulder:entindex(),
			Queue = false,
		})
	end
end

function treepeople_brain:TryCastSpear()
	if self:IsValidTarget() and self.hSpear:IsFullyCastable() then
		ExecuteOrderFromTable({
			UnitIndex = self:GetParent():entindex(),
			OrderType = DOTA_UNIT_ORDER_CAST_POSITION,
			Position  = self.chase_target:GetAbsOrigin(),
			AbilityIndex = self.hSpear:entindex(),
			Queue = false,
		})
	end
end

function treepeople_brain:GetCallRange()
	return 400 + self:GetParent():GetLevel() * 215
end

function treepeople_brain:GetEnemySearchRange()
	return 900 + self:GetParent():GetLevel() * 250
end

function treepeople_brain:OnIntervalThink()
	if IsClient() then return end
	
	-- we patrolling
	if ( self.mode == MODE.PATROL ) then
		-- look for target
		self.chase_target = self:LookForEnemy( self:GetEnemySearchRange() )
		if ( self:IsValidTarget() ) then
			-- we found the target
			self:ChangeModeTo( MODE.TAKE_POS )
		else
			self:ChangeModeTo( MODE.PATROL )
		end

	elseif ( self.mode == MODE.TAKE_POS ) then
		if ( self:IsValidTarget() ) then
			local range = ( self.chase_target:GetAbsOrigin() - self:GetParent():GetAbsOrigin() ):Length2D()
			if ( range < self:GetCallRange() ) and ( not self.dont_attack_bros ) then
				local bros = self:FindBros( self:GetCallRange(), self.chase_target:GetAbsOrigin() )
				if #bros > 2 then
					self.dont_attack_bros = true
					self:ChangeModeTo( MODE.ATTACK )
					
					self:TryCastHook()
					if RandomInt( 1, 2 ) == 1 then
						self:TryCastTagTeam()
					end
					
					if RandomInt( 1, 3 ) == 1 then
						self:TryCastBoulder()
					elseif RandomInt( 1, 3 ) == 1 then
						--self:TryCastSpear()
					end
					
					for u,unit in pairs(bros) do
						local mod = unit:FindModifierByName("treepeople_brain")
						if ( mod ~= nil ) and ( mod.mode ~= MODE.ATTACK ) then
							mod.dont_attack_bros = true
							mod.chase_target = self.chase_target
							mod:ChangeModeTo( MODE.ATTACK )
						end
					end
				else
					if RandomInt( 1, 2 ) == 1 then
						self:TryCastBoulder()
					else
						--self:TryCastSpear()
					end
					self:ChangeModeTo( MODE.PATROL )
				end
			else
				self:ChangeModeTo( MODE.TAKE_POS )
			end
		else
			-- lost the target
			self:ChangeModeTo( MODE.PATROL )
		end
	elseif ( self.mode == MODE.ATTACK ) then
		if ( not self:IsValidTarget() ) then
			-- target has dead, go back to patrolling
			self:ChangeModeTo( MODE.PATROL )
		else
			self:ChangeModeTo( MODE.ATTACK )
		end
	end
end

function treepeople_brain:MakeLevelUp()
	local parent = self:GetParent()
	
	if parent:GetLevel() == maxLevel then
		return
	end

	parent:CreatureLevelUp( 1 )
	
	local cnt = parent:GetAbilityCount()
	local abList = {}
	for i = 0, cnt - 1, 1 do
		local ab = parent:GetAbilityByIndex( i )

		if ( ab ~= nil ) and ( ab:GetHeroLevelRequiredToUpgrade() <= parent:GetLevel() ) and ( ab:GetMaxLevel() > ab:GetLevel() ) then
			table.insert( abList, ab )
			ab:SetLevel(  )
		end
	end
	
	--[[
	if #abList > 0 then
		local upAbility = abList[ RandomInt( 1, #abList ) ]
		upAbility:UpgradeAbility( false )
		--print( "upgraded " .. upAbility:GetAbilityName() )
	end
	]]--
	
	if parent:GetLevel() == 2 then
		parent:SetRenderColor( 150, 150, 255 )
	elseif parent:GetLevel() == 3 then
		parent:SetRenderColor( 150, 255, 150 )
	elseif parent:GetLevel() == 4 then
		parent:SetRenderColor( 255, 150, 150 )
	elseif parent:GetLevel() == 5 then
		parent:SetRenderColor( 40, 40, 40 )
	end
	
	parent:SetModelScale( 0.15 + parent:GetLevel() * 0.15 )
	parent:SetBaseMaxHealth( 150.0 + parent:GetLevel() * 170.0 )
	parent:SetDeathXP( parent:GetLevel() * 120.0 )
	parent:SetMinimumGoldBounty( 12.0 + parent:GetLevel() * 14.0 )
	parent:SetMaximumGoldBounty( 16.0 + parent:GetLevel() * 17.5 )
end

function treepeople_brain:OnDeath( event )
	if IsClient() then return end
	local parent = self:GetParent()
	
    if ( event.unit ~= parent ) and ( event.unit:GetTeamNumber() ~= parent:GetTeamNumber() ) and ( ( parent:GetAbsOrigin() - event.unit:GetAbsOrigin() ):Length2D() < 1200 ) then
        --event.attacker
		local oldLevel = parent:GetLevel()
		self.xp = self.xp + event.unit:GetDeathXP() * 0.35
		--print( "start getting levels..." )
		for i = oldLevel + 1, maxLevel, 1 do
			if XPTable[i] <= self.xp then
				self:MakeLevelUp()
			else
				break
			end
		end
		
		--print( "end getting levels..." )
    end
end

function treepeople_brain:OnDestroy()
	if IsClient() then return end

	treepeople_data.count = treepeople_data.count - 1
end

function treepeople_brain:GetModifierBaseAttack_BonusDamage( params )
	return self:GetParent():GetLevel() * 2.1
end

function treepeople_brain:DeclareFunctions()
    local funcs = {
        MODIFIER_EVENT_ON_DEATH,
		MODIFIER_PROPERTY_BASEATTACK_BONUSDAMAGE,
    }
    return funcs
end

function treepeople_brain:CheckState()
	if IsClient() then return 0 end
	
	local state = {
		[MODIFIER_STATE_NO_HEALTH_BAR] = true,
	}
	
	if self:GetParent():GetLevel() < 4 then
		state[MODIFIER_STATE_NOT_ON_MINIMAP_FOR_ENEMIES] = true
		state[MODIFIER_STATE_LOW_ATTACK_PRIORITY] = true
	end
	
	if not self:GetParent():IsAttacking() and GridNav:IsNearbyTree( self:GetParent():GetAbsOrigin(), 40, false ) and ( self:GetParent():GetLevel() < 4 ) then
		state[MODIFIER_STATE_INVISIBLE] = true
	end

	return state
end
