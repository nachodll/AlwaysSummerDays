#include "NW_I0_GENERIC"
#include "our_constants"

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
     sTarget = WpFurthestAltarRight();
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
    SetTeamName( sColor, "AlwaysSummer-Focus3-" + GetStringLowerCase( sColor ) );
}