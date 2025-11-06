#include "NW_I0_GENERIC"
#include "our_constants"


void T3_DetermineCombatRound( object oIntruder = OBJECT_INVALID, int nAI_Difficulty = 10 )
{
    DetermineCombatRound( oIntruder, nAI_Difficulty );
}

object T3_FindNearestAlly()
{
    object oNearest = GetNearestCreature(CREATURE_TYPE_REPUTATION, REPUTATION_TYPE_FRIEND, OBJECT_SELF, 1);
    if (oNearest == OBJECT_SELF)
    {
        oNearest = GetNearestCreature(CREATURE_TYPE_REPUTATION, REPUTATION_TYPE_FRIEND, OBJECT_SELF, 2);
    }
    return oNearest;
}

int T3_WizardStrategy()
{
    if (!IsWizard())
    {
        return FALSE;
    }

    // find nearest ally
    object oNearestAlly = T3_FindNearestAlly();

    //if the ally is in the combat
    if (GetIsObjectValid(oNearestAlly) && GetIsInCombat(oNearestAlly))
    {
        // help!!
        ActionMoveToObject(oNearestAlly, TRUE);
        SpeakString( "I GOT YOUR BACK SOLDIER!!! " + GetName(oNearestAlly), TALKVOLUME_SHOUT );

        return TRUE;
    }

    return FALSE;
}
// Called every heartbeat (i.e., every six seconds).
void T3_HeartBeat()
{

    if (GetIsInCombat())
    {
        SpeakString( "I AM IN COMBAT, AAAAAAAAAAAAAAAAAA", TALKVOLUME_SHOUT );
        T3_WizardStrategy();
        return;

    }

    string sTarget = GetLocalString( OBJECT_SELF, "TARGET" );
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
    }   /*
    else if (IsWizardLeft())
    {
     sTarget = WpClosestAltarLeft();
     SpeakString( "Target: "+ sTarget , TALKVOLUME_SHOUT );
    }
   else if (IsWizardRight())
    {
     sTarget = WpClosestAltarRight();
     SpeakString( "Target: "+ sTarget , TALKVOLUME_SHOUT );
    } */
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
    SetTeamName( sColor, "AlwaysSummer-Focus3-" + GetStringLowerCase( sColor ) );
}