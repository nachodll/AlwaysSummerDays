#include "NW_I0_GENERIC"
#include "our_constants"


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

// Speak the (x,y) position of every known enemy.
void T3_ReportEnemyPositions()
{
    int i;
    for (i = 1; i <= 7; i = i + 1)
    {
        object oEnemy = T3_GetEnemyByIndex(i);

        // Check that the enemy exists and is alive.
        if (GetIsObjectValid(oEnemy) && !GetIsDead(oEnemy))
        {
            location lEnemy = GetLocation(oEnemy);
            vector vPos = GetPositionFromLocation(lEnemy);
            string sMessage = "Enemy " + IntToString(i) +
                              " at (" +
                              FloatToString(vPos.x, 1) + ", " +
                              FloatToString(vPos.y, 1) + ", "+ ")";
            SpeakString(sMessage);
        }
        else
        {
            SpeakString("Enemy " + IntToString(i) + ": not valid or dead", TALKVOLUME_TALK);
        }
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

    if (GetIsInCombat())
    {
        SpeakString( "I AM IN COMBAT, AAAAAAAAAAAAAAAAAA", TALKVOLUME_SHOUT );
        return;

    }

    // Update enemy positions and report them
    T3_UpdateEnemyObjects();
    T3_ReportEnemyPositions();

    string sTarget = GetLocalString( OBJECT_SELF, "TARGET" );

    // Master should have other logic
    if (!IsMaster())
    {
        // Get the tag and object for the WpDoubler
        string sDoublerTag = WpDoubler();
        object oDoubler = GetObjectByTag(sDoublerTag);

        // Check for the nearest perceived enemy
        object oNearestEnemy = GetNearestPerceivedEnemy();

        // Check if doubler is close and no enemies are seen
        if (GetIsObjectValid(oDoubler) &&
            GetDistanceToObject(oDoubler) < 13.0 &&
            !GetIsObjectValid(oNearestEnemy))
        {
            if (sTarget != sDoublerTag)
            {
                SpeakString( "DOUBLER IS FREE" , TALKVOLUME_SHOUT );
                sTarget = sDoublerTag;
                SetLocalString( OBJECT_SELF, "TARGET", sTarget );
            }
        }
    }

    if (sTarget == "")
        return;

    object oTarget = GetObjectByTag( sTarget );
    if (!GetIsObjectValid( oTarget ))
        return;

    float fToTarget = GetDistanceToObject( oTarget );
    if (fToTarget > 0.5)
        ActionMoveToLocation( GetLocation( oTarget ), TRUE );


    return;
}

void T3_Spawn()
{
    {
    // Fallback if the logic does not work
    string sTarget = GetRandomTarget();

    if (IsMaster())
    {
     sTarget = WpFurthestAltarRight();
     SpeakString( "Target: "+ sTarget , TALKVOLUME_SHOUT );
    }
    else if (IsWizardLeft())
    {
     sTarget = WpClosestAltarLeft();
     SpeakString( "Target: "+ sTarget , TALKVOLUME_SHOUT );
    }
   else if (IsWizardRight())
    {
     sTarget = WpClosestAltarRight();
     SpeakString( "Target: "+ sTarget , TALKVOLUME_SHOUT );
    }
    else if (IsFighterLeft())
    {
     sTarget = WpFurthestAltarRight();
     SpeakString( "Target: "+ sTarget , TALKVOLUME_SHOUT );
    }
    else if (IsFighterRight())
    {
     sTarget = WpClosestAltarLeft();
     SpeakString( "Target: "+ sTarget , TALKVOLUME_SHOUT );
    }
    else if (IsClericLeft())
    {
     sTarget = TagMaster();
     SpeakString( "Target: "+ sTarget , TALKVOLUME_SHOUT );
    }
    else if (IsClericRight())
    {
     sTarget = WpClosestAltarRight();
     SpeakString( "Target: "+ sTarget , TALKVOLUME_SHOUT );
    }


    SetLocalString( OBJECT_SELF, "TARGET", sTarget );
    ActionMoveToLocation( GetLocation( GetObjectByTag( sTarget ) ), TRUE );
}
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
                    ActionAttack(oPerceived);
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
            T3_Spawn();
            break;
    }

    return;
}

void T3_Initialize( string sColor )
{
    SetTeamName( sColor, "AlwaysSummerDays-" + GetStringLowerCase( sColor ) );
}