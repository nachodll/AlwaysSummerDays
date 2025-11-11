#include "NW_I0_GENERIC"
#include "our_constants"

// ---------------------------- Debug functions -------------------------------
// Declare action together with their current role
void T3_DeclareAction(string sAction)
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
// Get objects with tag NPC_<ENEMY_COLOR>_<i> for i=1..7 and store them in the portal
void T3_UpdateEnemyObjects()
{
    string sMyColor = MyColor(OBJECT_SELF);
    if (sMyColor == "")
        return; // not on a team?

    string sEnemyColor;
    if (sMyColor == COLOR_RED) sEnemyColor = COLOR_BLUE; else sEnemyColor = COLOR_RED;

    object oPortal = MyPortal(OBJECT_SELF);
    if (!GetIsObjectValid(oPortal))
        return;

    int i;
    for (i = 1; i <= 7; i = i + 1)
    {
        string sTag = "NPC_" + sEnemyColor + "_" + IntToString(i);
        object oEnemy = GetObjectByTag(sTag);
        if (GetIsObjectValid(oEnemy))
            SetLocalObject(oPortal, "ENEMY_" + IntToString(i), oEnemy);
        else
            SetLocalObject(oPortal, "ENEMY_" + IntToString(i), OBJECT_INVALID);
    }
}

// Return the enemy object for index i (1..7)
object T3_GetEnemyByIndex(int iIndex)
{
    object oPortal = MyPortal(OBJECT_SELF);
    if (!GetIsObjectValid(oPortal))
        return OBJECT_INVALID;
    return GetLocalObject(oPortal, "ENEMY_" + IntToString(iIndex));
}


// ---------------------------- Strike attac functions -------------------------------
// Find the closest free altar
string T3_FindFreeAltar()
{
    float fBest = 9999.0;
    string sBest = "";

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
            sBest = sAltar;
        }
    }
    return sBest;
}

// Master updates strike target on the brazier
void T3_MasterUpdateStrikeTarget()
{
    if (!IsMaster())
        return;

    object oBrazier = GetObjectByTag("BRAZIER");
    if (!GetIsObjectValid(oBrazier))
        return;

    string sStrike = GetLocalString(oBrazier, "STRIKE_TARGET");

    // If current strike target is already ours AND has a guard, clear it so we pick a new one
    if (sStrike != "" && ClaimerOf(sStrike) == MyColor())
    {
        string sGuardTag = GetLocalString(oBrazier, "GUARD_" + sStrike);
        if (sGuardTag != "")
        {
            DeleteLocalString(oBrazier, "STRIKE_TARGET");
            sStrike = "";
        }
    }

    // If we have no active strike target, pick the closest free altar
    if (sStrike == "")
    {
        string sNew = T3_FindFreeAltar();
        if (sNew != "")
        {
            SetLocalString(oBrazier, "STRIKE_TARGET", sNew);
            T3_DeclareAction("Strike target set to " + sNew);
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
    //string sHunt = GetLocalString(oBrazier, "HUNT_TAG");
    //if (IsMaster() || IsFighterLeft() || IsClericLeft())
    //{
    //    if (sHunt != "")
    //        return;
    //}

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
                T3_DeclareAction("Holding " + sGuarding);
            }
            return;
        }
        else
        {
            // Lost the altar: stop guarding
            DeleteLocalString(OBJECT_SELF, "GUARDING_ALTAR");
            DeleteLocalString(oBrazier, "GUARD_" + sGuarding);
        }
    }

     string sStrike = GetLocalString(oBrazier, "STRIKE_TARGET");
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
            && GetLocalString(oBrazier, "GUARD_" + sStrike) == ""
            && GetDistanceToObject(oStrikeTarget) <= 3.5)
        {
            // Claim guard role
            string sMyTag = GetTag(OBJECT_SELF);
            SetLocalString(oBrazier, "GUARD_" + sStrike, sMyTag);
            SetLocalString(OBJECT_SELF, "GUARDING_ALTAR", sStrike);
            SetLocalString(OBJECT_SELF, "TARGET", sStrike);
            T3_DeclareAction("Assigned to guard " + sStrike);
            return;
        }

        // If we're not the guard, and a guard exists, then wait for Master pick a new target
        string sGuardTag = GetLocalString(oBrazier, "GUARD_" + sStrike);
        if (sGuardTag != "" && GetTag(OBJECT_SELF) != sGuardTag)
        {
            T3_DeclareAction("Waiting for master to re target");
            return;
        }
    }

    // Normal case: join / stay on current strike target
    string sCurrent = GetLocalString(OBJECT_SELF, "TARGET");
    if (sCurrent != sStrike)
    {
        SetLocalString(OBJECT_SELF, "TARGET", sStrike);
        T3_DeclareAction("Joining STRIKE on " + sStrike);
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

    // First update the isolation tick counters.
    T3_UpdateIsolationTicks();

    object oIsolated = T3_FindBestPersistentlyIsolatedEnemy(OBJECT_SELF);

    if (GetIsObjectValid(oIsolated))
    {
        string sTag = GetTag(oIsolated);
        SetLocalString(oBrazier, "HUNT_TAG", sTag);
        SetLocalString(OBJECT_SELF, "TARGET", sTag);

        T3_DeclareAction("HUNT: isolated enemy " + sTag);
    }
    else
    {
        DeleteLocalString(oBrazier, "HUNT_TAG");

    }
}


// Chosen hunters (M, FL adn CL)read HUNT_TAG from brazier and join the hunt if valid.
void T3_JoinHuntIfAvailable()
{
    object oBrazier = GetObjectByTag( "BRAZIER" );
    if (!GetIsObjectValid( oBrazier ))
        return;

    string sHunt = GetLocalString(oBrazier, "HUNT_TAG");
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
        T3_DeclareAction("Joining hunt on " + sHunt);
    }
}



// ---------------------------- Standard functions -------------------------------
// Called every combat round
void T3_DetermineCombatRound( object oIntruder = OBJECT_INVALID, int nAI_Difficulty = 10 )
{
    DetermineCombatRound( oIntruder, nAI_Difficulty );
}

// Called every heartbeat (i.e., every six seconds).
void T3_HeartBeat()
{
    //T3_UpdateEnemyObjects();
    //T3_MasterUpdateHuntTarget();       // hunt the lone (priority)
    T3_MasterUpdateStrikeTarget();     // strike target

    if (GetIsInCombat())
    {
        T3_DeclareAction("IN COMBAT - interrupting heartbeat");
        return;
    }

    //T3_JoinHuntIfAvailable(); // hunt team read target from brazier, if any
    T3_JoinStrikeAttack();    // strike team read target from brazier

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

void T3_Spawn()
{
    string sTarget;


    // --- Anchors: secure home altars and hold them ---
    if (IsWizardLeft())
    {
        sTarget = WpClosestAltarLeft();
    }
    else if (IsWizardRight())
    {
        sTarget = WpClosestAltarRight();
    }

    // Everyone else: go the strike target set by master
    //else
    //{
    //    object oBrazier = GetObjectByTag("BRAZIER");
    //    string sStrike = GetIsObjectValid(oBrazier)
    //                     ? GetLocalString(oBrazier, "STRIKE_TARGET")
    //                     : "";
    //
    //    if (sStrike == "")
    //        sStrike = WpDoubler(); // simple fallback
    //
    //    sTarget = sStrike;
    //    T3_DeclareAction("Strike team to " + sTarget);
    //}




    SetLocalString( OBJECT_SELF, "TARGET", sTarget );
    ActionMoveToLocation( GetLocation( GetObjectByTag( sTarget ) ), TRUE );
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
    }

    return;
}

void T3_Initialize( string sColor )
{
    SetTeamName( sColor, "AlwaysSummerDays-" + GetStringLowerCase( sColor ) );
}