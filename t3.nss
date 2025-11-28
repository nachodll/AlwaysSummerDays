#include "NW_I0_GENERIC"
#include "our_constants"

// ---------------------------- Debug functions -------------------------------
// Declare action together with their current role
void //T3_DeclareAction(string sAction)
{
    string sRole = "Unknown";
    if (IsMaster())        sRole = "Master";
    else if (IsWizardLeft())  sRole = "WizardLeft";
    else if (IsWizardRight()) sRole = "WizardRight";
    else if (IsClericLeft())  sRole = "ClericLeft";
    else if (IsClericRight()) sRole = "ClericRight";
    else if (IsFighterLeft()) sRole = "FighterLeft";
    else if (IsFighterRight())sRole = "FighterRight";

    string sMsg = "[" + sRole + "] " + sAction;
    SpeakString(sMsg, TALKVOLUME_SHOUT);
}

// ---------------------------- Custom functions -------------------------------
// Return the enemy object for index i (1..7)
object T3_GetEnemyByIndex(int iIndex)
{
    string sMyColor = MyColor(OBJECT_SELF);
    if (sMyColor == "")
        return OBJECT_INVALID; // not on a team?

    string sEnemyColor;
    if (sMyColor == COLOR_RED) sEnemyColor = COLOR_BLUE; else sEnemyColor = COLOR_RED;

    string sTag = "NPC_" + sEnemyColor + "_" + IntToString(iIndex);
    return GetObjectByTag(sTag);
}


// ---------------------------- Strike attac functions -------------------------------
// Find the closest altar that is free or claimed by the enemy
string T3_FindClosestContestableAltar()
{
    float fBest = 9999.0;
    string sClosest = "";

    int i;
    for (i = 0; i < 3; i++)
    {
        string sAltarWaypoint;
        if (i==0){
            sAltarWaypoint = WpDoubler();
        }
        else if (i==1){
            sAltarWaypoint = WpFurthestAltarRight();
        }
        else if (i==2){
            sAltarWaypoint = WpFurthestAltarLeft();
        }

        string sAltar = GetStringRight(sAltarWaypoint, GetStringLength(sAltarWaypoint) - 3);

        if (ClaimerOf(sAltar) == MyColor()){
            continue;
        }
        object oAltar = GetObjectByTag(sAltar);
        if (!GetIsObjectValid(oAltar))
            continue;

        float fDist = GetDistanceBetween(OBJECT_SELF, oAltar);
        if (fDist < fBest)
        {
            fBest = fDist;
            sClosest = sAltar;
        }
    }
    return sClosest;
}

// Find the closest free altar, not claimed altar by anyone
string T3_FindClosestUnclaimedAltar()
{
    float fBest = 9999.0;
    string sClosest = "";

    int i;
    for (i = 0; i < 3; i++)
    {
        string sAltarWaypoint;
        if (i==0){
            sAltarWaypoint = WpDoubler();
        }
        else if (i==1){
            sAltarWaypoint = WpFurthestAltarRight();
        }
        else if (i==2){
            sAltarWaypoint = WpFurthestAltarLeft();
        }

        string sAltar = GetStringRight(sAltarWaypoint, GetStringLength(sAltarWaypoint) - 3);

        // Only consider altars that are NOT claimed by anyone
        if (ClaimerOf(sAltar) != ""){
            continue;
        }
        object oAltar = GetObjectByTag(sAltar);
        if (!GetIsObjectValid(oAltar))
            continue;

        float fDist = GetDistanceBetween(OBJECT_SELF, oAltar);
        if (fDist < fBest)
        {
            fBest = fDist;
            sClosest = sAltar;
        }
    }
    return sClosest;
}

// Master updates strike target on the brazier
void T3_MasterUpdateStrikeTarget()
{
    if (!IsMaster())
        return;

    object oBrazier = GetObjectByTag("BRAZIER");
    if (!GetIsObjectValid(oBrazier))
        return;

    string sStrike = GetLocalString(oBrazier, "ASD_STRIKE_TARGET");

    // If current strike target is already ours AND has a guard, clear it so we pick a new one
    if (sStrike != "" && ClaimerOf(sStrike) == MyColor())
    {
        string sGuardTag = GetLocalString(oBrazier, "ASD_GUARD_" + sStrike);
        if (sGuardTag != "")
        {
            DeleteLocalString(oBrazier, "ASD_STRIKE_TARGET");
            sStrike = "";
        }
    }

    // If we have no active strike target, pick the closest free altar
    if (sStrike == "")
    {
        string sNew = T3_FindClosestContestableAltar();
        if (sNew != "")
        {
            SetLocalString(oBrazier, "ASD_STRIKE_TARGET", sNew);
            //T3_DeclareAction("Strike target set to " + sNew);
        }
    }
}

// Check for very close unclaimed altars and claim them (excludes wizards and base altars)
void T3_ClaimNearbyUnclaimedAltars()
{
    // Wizards and Master don't participate in opportunistic claiming
    if (IsWizardLeft() || IsWizardRight() || IsMaster())
        return;

    string sUnclaimed = T3_FindClosestUnclaimedAltar();
    if (sUnclaimed == "")
        return;

    // Skip base altars, we realy on wizards to claim those
    string sMyBaseLeft = GetStringRight(WpClosestAltarLeft(), GetStringLength(WpClosestAltarLeft()) - 3);
    string sMyBaseRight = GetStringRight(WpClosestAltarRight(), GetStringLength(WpClosestAltarRight()) - 3);
    
    if (sUnclaimed == sMyBaseLeft || sUnclaimed == sMyBaseRight)
        return;

    object oUnclaimed = GetObjectByTag(sUnclaimed);
    if (!GetIsObjectValid(oUnclaimed))
        return;

    float fDistToUnclaimed = GetDistanceBetween(OBJECT_SELF, oUnclaimed);
    
    // If we're at the unclaimed altar, claim it and become its guard
    if (fDistToUnclaimed <= 3.5)
    {
            // Altar is now ours - become its guardian
            object oBrazier = GetObjectByTag("BRAZIER");
            if (GetIsObjectValid(oBrazier))
            {
                string sGuard = GetLocalString(oBrazier, "ASD_GUARD_" + sUnclaimed);
                if (sGuard == "")
                {
                    string sMyTag = GetTag(OBJECT_SELF);
                    SetLocalString(oBrazier, "ASD_GUARD_" + sUnclaimed, sMyTag);
                    SetLocalString(OBJECT_SELF, "GUARDING_ALTAR", sUnclaimed);
                    SetLocalString(OBJECT_SELF, "TARGET", sUnclaimed);
                    //T3_DeclareAction("Claimed and guarding " + sUnclaimed);
                }
            }
        
    }
    // If there's an unclaimed altar within reasonable range, go to it
    else if (fDistToUnclaimed <= 16.0)
    {
        string sCurrent = GetLocalString(OBJECT_SELF, "TARGET");
        if (sCurrent != sUnclaimed)
        {
            SetLocalString(OBJECT_SELF, "TARGET", sUnclaimed);
            //T3_DeclareAction("Targeting unclaimed altar " + sUnclaimed);
        }
    }
}

void T3_JoinStrikeAttack()
{
    // Wizards never join the strike attack
    if (IsWizardLeft() || IsWizardRight())
        return;

    object oBrazier = GetObjectByTag("BRAZIER");
    if (!GetIsObjectValid(oBrazier))
        return;

    // Hunting roles will always prioritize the hunt
    string sHunt = GetLocalString(oBrazier, "ASD_HUNT_TARGET");
    if (IsMaster() || IsFighterLeft() || IsClericLeft())
    {
        if (sHunt != "")
            return;
    }

     // If we are already assigned as a guard, hold that altar as long as it's ours
    string sGuarding = GetLocalString(OBJECT_SELF, "GUARDING_ALTAR");
    if (sGuarding != "")
    {
        if (ClaimerOf(sGuarding) == MyColor())
        {
            string sCur = GetLocalString(OBJECT_SELF, "TARGET");
            if (sCur != sGuarding)
            {
                SetLocalString(OBJECT_SELF, "TARGET", sGuarding);
                //T3_DeclareAction("Holding " + sGuarding);
            }
            return;
        }
        else
        {
            // Lost the altar: stop guarding
            DeleteLocalString(OBJECT_SELF, "GUARDING_ALTAR");
            DeleteLocalString(oBrazier, "ASD_GUARD_" + sGuarding);
        }
    }

     string sStrike = GetLocalString(oBrazier, "ASD_STRIKE_TARGET");
    if (sStrike == "")
        return;

    object oStrikeTarget = GetObjectByTag(sStrike);
    if (!GetIsObjectValid(oStrikeTarget))
        return;

    // If this strike altar is already ours, maybe assign a guard
    if (ClaimerOf(sStrike) == MyColor())
    {
        // Only non-Master can become guard
        if (!IsMaster()
            && GetLocalString(oBrazier, "ASD_GUARD_" + sStrike) == ""
            && GetDistanceToObject(oStrikeTarget) <= 3.5)
        {
            // Claim guard role
            string sMyTag = GetTag(OBJECT_SELF);
            SetLocalString(oBrazier, "ASD_GUARD_" + sStrike, sMyTag);
            SetLocalString(OBJECT_SELF, "GUARDING_ALTAR", sStrike);
            SetLocalString(OBJECT_SELF, "TARGET", sStrike);
            //T3_DeclareAction("Assigned to guard " + sStrike);
            return;
        }

        // If we're not the guard, and a guard exists, then wait for Master pick a new target
        string sGuardTag = GetLocalString(oBrazier, "ASD_GUARD_" + sStrike);
        if (sGuardTag != "" && GetTag(OBJECT_SELF) != sGuardTag)
        {
            //T3_DeclareAction("Waiting for master to re target");
            return;
        }
    }

    // Normal case: join / stay on current strike target
    string sCurrent = GetLocalString(OBJECT_SELF, "TARGET");
    if (sCurrent != sStrike)
    {
        SetLocalString(OBJECT_SELF, "TARGET", sStrike);
        //T3_DeclareAction("Joining STRIKE on " + sStrike);
    }

}



// ---------------------------- Hunt the lone functions -------------------------------
const float ISO_RANGE = 20.0;           // Enemy is "alone" if nearest ally is > 20m away.
const float ISO_MAX_HUNT_DIST = 80.0;   // Don't hunt targets across the whole map.
const int ISO_REQUIRED_TICKS = 3;    // Only hunt enemies who are persistently isolated.

// Check whether a specific enemy oE is curretnly isolated from its allies
int T3_IsEnemyCurrentlyIsolated(object oE)
{
    if (!GetIsObjectValid(oE) || GetIsDead(oE))
        return FALSE;

    int i;
    float fClosest = 9999.0;
    for (i = 1; i <= 7; i = i + 1)
    {
        object oOther = T3_GetEnemyByIndex(i);
        if (!GetIsObjectValid(oOther) || GetIsDead(oOther) || oOther == oE)
            continue;

        float fDist = GetDistanceBetween(oE, oOther);
        if (fDist < fClosest)
            fClosest = fDist;
    }

    return (fClosest > ISO_RANGE);
}

// Keep track of isolation through time
void T3_UpdateIsolationTicks()
{
    object oPortal = MyPortal(OBJECT_SELF);
    if (!GetIsObjectValid(oPortal))
        return;

    int i;
    for (i = 1; i <= 7; i = i + 1)
    {
        object oE = T3_GetEnemyByIndex(i);
        string sKey = "ISO_TICKS_" + IntToString(i);

        if (GetIsObjectValid(oE) && !GetIsDead(oE) && T3_IsEnemyCurrentlyIsolated(oE))
        {
            int nTicks = GetLocalInt(oPortal, sKey);
            SetLocalInt(oPortal, sKey, nTicks + 1);
        }
        else
        {
            // Reset streak if not isolated
            SetLocalInt(oPortal, sKey, 0);
        }
    }
}

// Scans for a good persistently isolated enemy to hunt close to oHunter
object T3_FindBestPersistentlyIsolatedEnemy(object oHunter)
{
    object oPortal = MyPortal(oHunter);
    if (!GetIsObjectValid(oPortal))
        return OBJECT_INVALID;

    int i;
    float fBestDist = 99999.0;
    object oBest = OBJECT_INVALID;

    for (i = 1; i <= 7; i = i + 1)
    {
        object oE = T3_GetEnemyByIndex(i);
        if (!GetIsObjectValid(oE) || GetIsDead(oE))
            continue;

        // Require persistent isolation
        int nTicks = GetLocalInt(oPortal, "ISO_TICKS_" + IntToString(i));
        if (!(nTicks >= ISO_REQUIRED_TICKS))
            continue;

        float fDist = GetDistanceBetween(oHunter, oE);
        if (fDist > ISO_MAX_HUNT_DIST)
            continue;

        if (fDist < fBestDist)
        {
            fBestDist = fDist;
            oBest = oE;
        }
    }

    return oBest;
}

// Only master sets the team-wide hunt target on the portal.
void T3_MasterUpdateHuntTarget()
{
    if (!IsMaster())
        return;

    object oBrazier = GetObjectByTag( "BRAZIER" );
    if (!GetIsObjectValid( oBrazier ))
        return;

    // Check if current hunt target is dead or invalid clear it
    string sCurrentHunt = GetLocalString(oBrazier, "ASD_HUNT_TARGET");
    if (sCurrentHunt != "")
    {
        object oCurrentTarget = GetObjectByTag(sCurrentHunt);
        if (!GetIsObjectValid(oCurrentTarget) || GetIsDead(oCurrentTarget))
        {
            DeleteLocalString(oBrazier, "ASD_HUNT_TARGET");
            //T3_DeclareAction("Hunt target died - clearing");
            sCurrentHunt = "";
        }
    }

    // First update the isolation tick counters.
    T3_UpdateIsolationTicks();

    object oIsolated = T3_FindBestPersistentlyIsolatedEnemy(OBJECT_SELF);

    if (GetIsObjectValid(oIsolated))
    {
        string sTag = GetTag(oIsolated);
        SetLocalString(oBrazier, "ASD_HUNT_TARGET", sTag);
        SetLocalString(OBJECT_SELF, "TARGET", sTag);

        //T3_DeclareAction("HUNT: isolated enemy " + sTag);
    }
}


// Chosen hunters (M, FL adn CL)read ASD_HUNT_TARGET from brazier and join the hunt if valid.
void T3_JoinHuntIfAvailable()
{
    object oBrazier = GetObjectByTag( "BRAZIER" );
    if (!GetIsObjectValid( oBrazier ))
        return;

    string sHunt = GetLocalString(oBrazier, "ASD_HUNT_TARGET");
    if (sHunt == "")
        return;

    object oHuntTarget = GetObjectByTag(sHunt);
    if (!GetIsObjectValid(oHuntTarget) || GetIsDead(oHuntTarget))
        return;

    // Only these three roles participate in the 3v1 hunt.
    if (!(IsMaster() || IsClericLeft() || IsFighterLeft()))
        return;

    // Set our local target to the hunt target if not already set.
    string sCurrent = GetLocalString(OBJECT_SELF, "TARGET");
    if (sCurrent != sHunt)
    {
        SetLocalString(OBJECT_SELF, "TARGET", sHunt);
        //T3_DeclareAction("Joining hunt on " + sHunt);
    }
}

// ---------------------- Individual Unit Code Functions -------------------------

// Get local focus target in a combat
object T3_GetFocusTarget()
{

    // Next, pick lowest HP enemy in reasonable range
    int i;
    object oBest = OBJECT_INVALID;
    int nBestHP = 99999;

    for (i = 1; i <= 7; i = i + 1)
    {
        object oE = T3_GetEnemyByIndex(i);
        if (!GetIsObjectValid(oE) || GetIsDead(oE))
            continue;

        if (!IsWizard())
        {
            if (GetDistanceBetween(OBJECT_SELF, oE) > 10.0)
                continue;
        }
        else
        {
            if (GetDistanceBetween(OBJECT_SELF, oE) > 40.0)
                continue;
        }

        int nHP = GetCurrentHitPoints(oE);
        if (nHP < nBestHP)
        {
            nBestHP = nHP;
            oBest = oE;
        }
    }

    if (GetIsObjectValid(oBest))
        return oBest;

    // Fallback: nearest enemy
    object oNearest = GetNearestCreature(CREATURE_TYPE_REPUTATION, REPUTATION_TYPE_ENEMY, OBJECT_SELF);
    if (GetIsObjectValid(oNearest) && !GetIsDead(oNearest))
        return oNearest;

    return OBJECT_INVALID;
}

// Cleric - heal nearby allies if damaged
int T3_ClericHealIfNeeded()
{
    if (!IsCleric() || !GetIsInCombat())
        return FALSE;

    object oBest = OBJECT_INVALID;
    int nWorstHealth = 5;

    // Scan for nearby allies
    object oScan = GetNearestCreature(CREATURE_TYPE_REPUTATION, REPUTATION_TYPE_FRIEND, OBJECT_SELF, 1, CREATURE_TYPE_PERCEPTION, PERCEPTION_SEEN);
    int nIndex = 1;
    while (GetIsObjectValid(oScan) && nIndex < 10)
    {
        if (SameTeam(oScan))
        {
            float fDist = GetDistanceBetween(OBJECT_SELF, oScan);
            if (fDist <= 15.0)
            {
                int nHealth = GetHealth(oScan);
                if (nHealth > 0 && nHealth < nWorstHealth)
                {
                    nWorstHealth = nHealth;
                    oBest = oScan;
                }
            }
        }
        ++nIndex;
        oScan = GetNearestCreature(CREATURE_TYPE_REPUTATION, REPUTATION_TYPE_FRIEND, OBJECT_SELF, nIndex, CREATURE_TYPE_PERCEPTION, PERCEPTION_SEEN);
    }

    if (!GetIsObjectValid(oBest))
        return FALSE;

    // Choose best available heal spell
    int nSpell = -1;
    if (GetHasSpell(SPELL_CURE_CRITICAL_WOUNDS) > 0)
        nSpell = SPELL_CURE_CRITICAL_WOUNDS;
    else if (GetHasSpell(SPELL_CURE_SERIOUS_WOUNDS) > 0)
        nSpell = SPELL_CURE_SERIOUS_WOUNDS;
    else if (GetHasSpell(SPELL_CURE_MODERATE_WOUNDS) > 0)
        nSpell = SPELL_CURE_MODERATE_WOUNDS;
    else if (GetHasSpell(SPELL_CURE_LIGHT_WOUNDS) > 0)
        nSpell = SPELL_CURE_LIGHT_WOUNDS;

    if (nSpell == -1)
        return FALSE;

    ClearAllActions();
    ActionCastSpellAtObject(nSpell, oBest, METAMAGIC_ANY, FALSE, 0, PROJECTILE_PATH_TYPE_DEFAULT, FALSE);
    //T3_DeclareAction("Healing ally " + GetTag(oBest));
    return TRUE;
}

// Wizard - use Magic Missile for low HP targets, big spells otherwise
int T3_WizardOffense(object oEnemy)
{
    if (!IsWizard() || !GetIsObjectValid(oEnemy))
        return FALSE;

    // Check if enemy HP is below 20% - if so, use Magic Missile to finish them off
    int nCurrentHP = GetCurrentHitPoints(oEnemy);
    int nMaxHP = GetMaxHitPoints(oEnemy);
    float fHPRatio = 0.0;

    if (nMaxHP > 0)
        fHPRatio = IntToFloat(nCurrentHP) / IntToFloat(nMaxHP);

    int nSpell = -1;

    // If enemy is below 20% HP, use Magic Missile (guaranteed hit, don't waste big spells)
    if (fHPRatio < 0.20 && GetHasSpell(SPELL_MAGIC_MISSILE) > 0)
    {
        nSpell = SPELL_MAGIC_MISSILE;
        ClearAllActions();
        ActionCastSpellAtObject(nSpell, oEnemy, METAMAGIC_ANY, FALSE, 0, PROJECTILE_PATH_TYPE_DEFAULT, FALSE);
        //T3_DeclareAction("Finishing off low HP enemy with Magic Missile: " + GetTag(oEnemy));
        return TRUE;
    }

    float fDistToEnemy = GetDistanceBetween(OBJECT_SELF, oEnemy);

    // Use this order of spells within 17 meters (some space to account for walking out of range)
    if (fDistToEnemy <= 17.0)
    {
        if (GetHasSpell(SPELL_FLAME_ARROW) > 0)
            nSpell = SPELL_FLAME_ARROW;
        else if (GetHasSpell(SPELL_LIGHTNING_BOLT) > 0)
            nSpell = SPELL_LIGHTNING_BOLT;
        else if (GetHasSpell(SPELL_MELFS_ACID_ARROW) > 0)
            nSpell = SPELL_MELFS_ACID_ARROW;
        else if (GetHasSpell(SPELL_MAGIC_MISSILE) > 0)
            nSpell = SPELL_MAGIC_MISSILE;
    }
    // Use this order of spells within 35 meters (some space to account for walking out of range)
    else if (fDistToEnemy <= 35.0)
    {
        if (GetHasSpell(SPELL_FLAME_ARROW) > 0)
            nSpell = SPELL_FLAME_ARROW;
        else if (GetHasSpell(SPELL_MELFS_ACID_ARROW) > 0)
            nSpell = SPELL_MELFS_ACID_ARROW;
        else if (GetHasSpell(SPELL_MAGIC_MISSILE) > 0)
            nSpell = SPELL_MAGIC_MISSILE;
    }

    if (nSpell == -1)
        return FALSE; // fall back to default AI

    ClearAllActions();
    ActionCastSpellAtObject(nSpell, oEnemy, METAMAGIC_ANY, FALSE, 0, PROJECTILE_PATH_TYPE_DEFAULT, FALSE);
    //T3_DeclareAction("Casting spell at " + GetTag(oEnemy));
    return TRUE;
}

// Fighters: prefer melee on focus target
int T3_FighterOffense(object oEnemy)
{
    if (!IsFighter() || !GetIsObjectValid(oEnemy))
        return FALSE;

    ClearAllActions();
    ActionEquipMostDamagingMelee();
    ActionAttack(oEnemy);
    //T3_DeclareAction("Attacking " + GetTag(oEnemy) + " in melee");
    return TRUE;
}


// ---------------------------- Standard functions -------------------------------
// Called every combat round
void T3_DetermineCombatRound(object oIntruder = OBJECT_INVALID, int nAI_Difficulty = 10)
{
    // Get targets using GetFocusTarget
    object oEnemy = T3_GetFocusTarget();
    if (!GetIsObjectValid(oEnemy))
    {
        // No special logic possible, fall back to default AI
        DetermineCombatRound(oIntruder, nAI_Difficulty);
        return;
    }
    // Role-specific combat
    if (IsWizard())
    {
        if (T3_WizardOffense(oEnemy))
            return;
    }
    else if (IsCleric())
    {
        // Try to heal allies first
        if (T3_ClericHealIfNeeded())
            return;

        // Otherwise behave roughly like a fighter
        if (T3_FighterOffense(oEnemy))
            return;
    }
    else if (IsFighter())
    {
        if (T3_FighterOffense(oEnemy))
            return;
    }

    // Fallback to default Bioware AI if nothing else triggered
    DetermineCombatRound(oIntruder, nAI_Difficulty);
}

// Called every heartbeat (i.e., every six seconds).
void T3_HeartBeat()
{
    T3_MasterUpdateHuntTarget();       // hunt the lone (priority)
    T3_MasterUpdateStrikeTarget();     // strike target

    if (GetIsInCombat())
    {
        //T3_DeclareAction("IN COMBAT - interrupting heartbeat");
        return;
    }

    T3_JoinHuntIfAvailable(); // hunt team read target from brazier, if any
    T3_JoinStrikeAttack();    // strike team read target from brazier
    T3_ClaimNearbyUnclaimedAltars(); // opportunistically claim nearby unclaimed altars

    // Keep moving towards the target
    string sTarget = GetLocalString( OBJECT_SELF, "TARGET" );
    if (sTarget == "")
        return;
    object oTarget = GetObjectByTag( sTarget );
    if (!GetIsObjectValid( oTarget ))
        return;

    float fToTarget = GetDistanceToObject( oTarget );
    if (fToTarget > 0.5)
    {
        ActionMoveToLocation( GetLocation( oTarget ), TRUE );
        //T3_DeclareAction("Moving to " + sTarget);
    }


    return;
}

// We rely on Heartbeat for everything, spawn will only handle staff that is not update on Heartbeat
void T3_Spawn()
{
    string sTarget;

    // Anchors: secure home altars and hold them
    if (IsWizardLeft())
    {
        sTarget = WpClosestAltarLeft();
    }
    else if (IsWizardRight())
    {
        sTarget = WpClosestAltarRight();
    }
        SetLocalString(OBJECT_SELF, "TARGET", sTarget);
}


void T3_UserDefined( int Event )
{
    switch (Event)
    {
        // The NPC has just been attacked.
        case EVENT_ATTACKED:
            break;

        // The NPC was damaged.
        case EVENT_DAMAGED:
            break;

        // At the end of one round of combat.
        case EVENT_END_COMBAT_ROUND:
            break;

        // Every heartbeat (i.e., every six seconds).
        case EVENT_HEARTBEAT:
            T3_HeartBeat();
            break;

        // Whenever the NPC perceives a new creature.
        case EVENT_PERCEIVE:
            break;

        // When a spell is cast at the NPC.
        case EVENT_SPELL_CAST_AT:
            break;

        // Whenever the NPC's inventory is disturbed.
        case EVENT_DISTURBED:
            break;

        // Whenever the NPC dies.
        case EVENT_DEATH:
            break;

        // When the NPC has just been spawned.
        case EVENT_SPAWN:
            T3_Spawn();
            break;
        // Called once for each team per 6 seconds.
        // Note: You cannot use SpeakString() in this event as the caller is not an object.
        // Instead, if you want to show a text above a creature oPC, use FloatingTextStringOnCreature().
        case EVENT_AREA:
            object oPC = GetFirstPC();
            FloatingTextStringOnCreature( "T1 Area Event", oPC, FALSE );
            break;
    }

    return;
}

void T3_Initialize( string sColor )
{
    SetTeamName( sColor, "AlwaysSummerDays-" + GetStringLowerCase( sColor ) );
}