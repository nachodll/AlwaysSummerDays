#include "NW_I0_GENERIC"
#include "our_constants"

// ---------------------------- Debug functions -------------------------------
// Declare action together with their current role
void TASD_DeclareAction(string sAction)
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
void TASD_UpdateEnemyObjects()
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
object TASD_GetEnemyByIndex(int iIndex)
{
    object oPortal = MyPortal(OBJECT_SELF);
    if (!GetIsObjectValid(oPortal))
        return OBJECT_INVALID;
    return GetLocalObject(oPortal, "ENEMY_" + IntToString(iIndex));
}

// Find the closest free altar
string TASD_FindFreeAltar()
{
    float fBest = 9999.0;
    string sBest = "";

    int i;
    for (i = 0; i < 4; i++)
    {
        string sAltar;
        if (i==0){
            sAltar = ALTAR_RED_1;
        }
        else if (i==1){
            sAltar = ALTAR_RED_2;
        }
        else if (i==2){
            sAltar = ALTAR_BLUE_1;
        }
        else if (i==3){
            sAltar = ALTAR_BLUE_2;
        }

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
void TASD_MasterUpdateStrikeTarget()
{
    if (!IsMaster())
        return;

    object oBrazier = GetObjectByTag("BRAZIER");
    if (!GetIsObjectValid(oBrazier))
        return;

    string sStrike = TASD_FindFreeAltar();
    if (sStrike != "")
    {
        SetLocalString(oBrazier, "STRIKE_TARGET", sStrike);
        TASD_DeclareAction("Strike target set to " + sStrike);
    }
}

void TASD_JoinStrikeAttack()
{
    // Wizards never join the strike attack
    if (IsWizardLeft() || IsWizardRight())
        return;

    object oBrazier = GetObjectByTag("BRAZIER");
    if (!GetIsObjectValid(oBrazier))
        return;

    string sStrike = GetLocalString(oBrazier, "STRIKE_TARGET");
    if (sStrike == "")
        return;

    object oStrikeTarget = GetObjectByTag(sStrike);
    if (!GetIsObjectValid(oStrikeTarget))
        return;

    // Hunting roles will always prioritize the hunt
    string sHunt = GetLocalString(oBrazier, "HUNT_TAG");
    if (IsMaster() || IsFighterLeft() || IsClericLeft())
    {
        if (sHunt != "")
            return;
    }

    string sCurrent = GetLocalString(OBJECT_SELF, "TARGET");
    if (sCurrent != sStrike)
    {
        SetLocalString(OBJECT_SELF, "TARGET", sStrike);
        TASD_DeclareAction("Joining STRIKE on " + sStrike);
    }
}



// ---------------------------- Hunt the lone functions -------------------------------
const float ISO_RANGE = 20.0;           // Enemy is "alone" if nearest ally is > 20m away.
const float ISO_MAX_HUNT_DIST = 80.0;   // Don't hunt targets across the whole map.
const int ISO_REQUIRED_TICKS = 3;    // Only hunt enemies who are persistently isolated.

// Check whether a specific enemy oE is curretnly isolated from its allies
int TASD_IsEnemyCurrentlyIsolated(object oE)
{
    if (!GetIsObjectValid(oE) || GetIsDead(oE))
        return FALSE;

    int i;
    float fClosest = 9999.0;
    for (i = 1; i <= 7; i = i + 1)
    {
        object oOther = TASD_GetEnemyByIndex(i);
        if (!GetIsObjectValid(oOther) || GetIsDead(oOther) || oOther == oE)
            continue;

        float fDist = GetDistanceBetween(oE, oOther);
        if (fDist < fClosest)
            fClosest = fDist;
    }

    return (fClosest > ISO_RANGE);
}

// Keep track of isolation through time
void TASD_UpdateIsolationTicks()
{
    object oPortal = MyPortal(OBJECT_SELF);
    if (!GetIsObjectValid(oPortal))
        return;

    int i;
    for (i = 1; i <= 7; i = i + 1)
    {
        object oE = TASD_GetEnemyByIndex(i);
        string sKey = "ISO_TICKS_" + IntToString(i);

        if (GetIsObjectValid(oE) && !GetIsDead(oE) && TASD_IsEnemyCurrentlyIsolated(oE))
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
object TASD_FindBestPersistentlyIsolatedEnemy(object oHunter)
{
    object oPortal = MyPortal(oHunter);
    if (!GetIsObjectValid(oPortal))
        return OBJECT_INVALID;

    int i;
    float fBestDist = 99999.0;
    object oBest = OBJECT_INVALID;

    for (i = 1; i <= 7; i = i + 1)
    {
        object oE = TASD_GetEnemyByIndex(i);
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
void TASD_MasterUpdateHuntTarget()
{
    if (!IsMaster())
        return;

    object oBrazier = GetObjectByTag( "BRAZIER" );
    if (!GetIsObjectValid( oBrazier ))
        return;

    // First update the isolation tick counters.
    TASD_UpdateIsolationTicks();

    object oIsolated = TASD_FindBestPersistentlyIsolatedEnemy(OBJECT_SELF);

    if (GetIsObjectValid(oIsolated))
    {
        string sTag = GetTag(oIsolated);
        SetLocalString(oBrazier, "HUNT_TAG", sTag);
        SetLocalString(OBJECT_SELF, "TARGET", sTag);

        TASD_DeclareAction("HUNT: isolated enemy " + sTag);
    }
    else
    {
        DeleteLocalString(oBrazier, "HUNT_TAG");

    }
}


// Chosen hunters (M, FL adn CL)read HUNT_TAG from brazier and join the hunt if valid.
void TASD_JoinHuntIfAvailable()
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
        TASD_DeclareAction("Joining hunt on " + sHunt);
    }
}



// ---------------------------- Standard functions -------------------------------
// Called every combat round
void TASD_DetermineCombatRound( object oIntruder = OBJECT_INVALID, int nAI_Difficulty = 10 )
{
    DetermineCombatRound( oIntruder, nAI_Difficulty );
}

// Called every heartbeat (i.e., every six seconds).
void TASD_HeartBeat()
{
    TASD_UpdateEnemyObjects();
    TASD_MasterUpdateHuntTarget();       // hunt the lone (priority)
    TASD_MasterUpdateStrikeTarget();     // strike target

    if (GetIsInCombat())
    {
        TASD_DeclareAction("IN COMBAT - interrupting heartbeat");
        return;
    }

    // Master and designated hunters adopt the hunt target if any.
    TASD_JoinHuntIfAvailable();
    // Master and strike team adop the strike target
    TASD_JoinStrikeAttack();

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
        TASD_DeclareAction("Moving to " + sTarget);
    }


    return;
}

void TASD_Spawn()
{
    string sTarget = GetRandomTarget();


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
    else
    {
        object oBrazier = GetObjectByTag("BRAZIER");
        string sStrike = GetIsObjectValid(oBrazier)
                         ? GetLocalString(oBrazier, "STRIKE_TARGET")
                         : "";

        if (sStrike == "")
            sStrike = GetRandomTarget(); // simple fallback

        sTarget = sStrike;
        TASD_DeclareAction("Strike team to " + sTarget);
    }




    SetLocalString( OBJECT_SELF, "TARGET", sTarget );
    ActionMoveToLocation( GetLocation( GetObjectByTag( sTarget ) ), TRUE );
}

void TASD_UserDefined( int Event )
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
            TASD_HeartBeat();
            break;


        // Whenever the NPC perceives a new creature.
        case EVENT_PERCEIVE:
        {
            // Get the creature that triggered this event
            object oPerceived = GetLastPerceived();

            // Check if the perceived creature is an enemy
            if (GetIsEnemy(oPerceived))
            {
                // Check if the enemy is within 3.0 meters
                if (GetDistanceToObject(oPerceived) < 3.0)
                {

                    // Stop current movement and attack the close-range enemy
                    ClearAllActions();
                    DetermineCombatRound(oPerceived);
                }
                else
                {
                    // --- Keep running towards target ---
                    // The enemy is far away, so ignore them and
                    // resume moving to the main target waypoint.
                    string sTarget = GetLocalString(OBJECT_SELF, "TARGET");
                    if (sTarget != "") // Only resume if we have a valid target
                    {
                        object oTarget = GetObjectByTag(sTarget);
                        if (GetIsObjectValid(oTarget))
                        {
                            // Re-issue the move command because this event
                            // interrupted the previous action.
                            ActionMoveToLocation(GetLocation(oTarget), TRUE);
                        }
                    }
                }
            }
            break;
        }



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
            TASD_Spawn();
            break;
    }

    return;
}

void TASD_Initialize( string sColor )
{
    SetTeamName( sColor, "AlwaysSummerDays-" + GetStringLowerCase( sColor ) );
}