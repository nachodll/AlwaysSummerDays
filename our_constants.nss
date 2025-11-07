const int EVENT_SPAWN = 3500;
const int EVENT_DEATH = 1007;
const string COLOR_BLUE = "BLUE";
const string COLOR_RED = "RED";
const string DOUBLER = "DOUBLER";
const string ALTAR_BLUE_1 = "ALTAR_BLUE_1";
const string ALTAR_BLUE_2 = "ALTAR_BLUE_2";
const string ALTAR_RED_1 = "ALTAR_RED_1";
const string ALTAR_RED_2 = "ALTAR_RED_2";

// Return the color of oObject, either COLOR_RED or COLOR_BLUE. If oObject
// belongs to neither team, return an empty string.
string MyColor( object oObject = OBJECT_SELF )
{
    if (!GetIsObjectValid( oObject ))
        return "";
    string sColor = GetLocalString( oObject, "COLOR" );
    if (sColor != COLOR_RED && sColor != COLOR_BLUE)
        return "";
    return sColor;
}

// Return the color of the opponent team of oObject.
string OpponentColor( object oObject = OBJECT_SELF )
{
    if (!GetIsObjectValid( oObject ))
        return "";
    string sColor = GetLocalString( oObject, "COLOR" );
    if (sColor == COLOR_BLUE)
    {
        return COLOR_RED;
    }
    else if (sColor == COLOR_RED)
    {
        return COLOR_BLUE;
    }
    else
        return "";
}

// Return the tag of the waypoint that identifies the doubler space.
string WpDoubler()
{
    return "WP_" + DOUBLER;
}

// Return the tag of the waypoint that identifies the altar that is at the side
// of the oObject starting area, to the right. If the function is called with
// an oObject that belongs to neither team, return an empty string.
string WpClosestAltarRight( object oObject = OBJECT_SELF )
{
    string sColor = MyColor( oObject );
    if (sColor == "")
        return "";
    return "WP_ALTAR_" + sColor + "_1";
}

// Return the tag of the waypoint that identifies the altar that is at the side
// of the oObject starting area, to the left. If the function is called with
// an oObject that belongs to neither team, return an empty string.
string WpClosestAltarLeft( object oObject = OBJECT_SELF )
{
    string sColor = MyColor( oObject );
    if (sColor == "")
        return "";
    return "WP_ALTAR_" + sColor + "_2";
}

// Return the tag of the waypoint that identifies the altar that is at the opposite side
// of the oObject starting area, to the right. If the function is called with
// an oObject that belongs to neither team, return an empty string.
string WpFurthestAltarRight( object oObject = OBJECT_SELF )
{
    string sColor = OpponentColor( oObject );
    if (sColor == "")
        return "";
    return "WP_ALTAR_" + sColor + "_2";
}

// Return the tag of the waypoint that identifies the altar that is at the opposite side
// of the oObject starting area, to the left. If the function is called with
// an oObject that belongs to neither team, return an empty string.
string WpFurthestAltarLeft( object oObject = OBJECT_SELF )
{
    string sColor = OpponentColor( oObject );
    if (sColor == "")
        return "";
    return "WP_ALTAR_" + sColor + "_1";
}

// Return the color that identifies the team that has claimed a certain altar.
// Call with ALTAR_RED_1, ALTAR_RED_2, ALTAR_BLUE_1, ALTAR_BLUE_2, or DOUBLER.
// Returns either COLOR_RED or COLOR_BLUE, or an empty string if called with a
// wrong parameter.
string ClaimerOf( string sAltar )
{
    object oAltar = GetObjectByTag( sAltar );
    if (!GetIsObjectValid( oAltar ))
        return "";
    string sOwner = GetLocalString( oAltar, "OWNER" );
    if (sOwner != COLOR_RED && sOwner != COLOR_BLUE)
        return "";
    return sOwner;
}

// Return the Portal object for oObject. This portal is indestructable, and can
// be used to store any variables that the object wants to keep track of. Note
// that the object is a creature, and can be destroyed, and thus cannot store
// its own knowledge. The function returns OBJECT_INVALID if the oObject has
// no portal (i.e., is not on a team).
object MyPortal( object oObject = OBJECT_SELF )
{
    if (!GetIsObjectValid( oObject ))
        return OBJECT_INVALID;
    string sPortal = "PORTAL_" + MyColor( oObject ) + "_" + IntToString( GetLocalInt( oObject, "INDEX" ) );
    return GetObjectByTag( sPortal );
}

// Return the score achieved by the team with color sColor, for altar sAltar.
// Call with ALTAR_RED_1, ALTAR_RED_2, ALTAR_BLUE_1, ALTAR_BLUE_2, or DOUBLER
// for sAltar, and COLOR_RED or COLOR_BLUE for sColor.
int GetAltarScore( string sColor, string sAltar )
{
    object oAltar = GetObjectByTag( sAltar );
    if (!GetIsObjectValid( oAltar ))
        return 0;
    return GetLocalInt( oAltar, "SCORE_" + sColor );
}

// Get the total score for the team with color sColor. Call with COLOR_RED or
// COLOR_BLUE.
int GetScore( string sColor )
{
    int iScore = 0;

    iScore = iScore + GetAltarScore( sColor, ALTAR_RED_1 );
    iScore = iScore + GetAltarScore( sColor, ALTAR_RED_2 );
    iScore = iScore + GetAltarScore( sColor, ALTAR_BLUE_1 );
    iScore = iScore + GetAltarScore( sColor, ALTAR_BLUE_2 );

    return iScore;
}

// Sets the name of a team, call this with your color as
// first parameter, and the desired name as second parameter.
void SetTeamName( string sColor, string sName )
{
    object oBrazier = GetObjectByTag( "BRAZIER" );
    if (!GetIsObjectValid( oBrazier ))
        return;

    SetLocalString( oBrazier, "TEAM_" + sColor, sName );

    return;
}

// Gets the name of a team, by color
string GetTeamName( string sColor )
{
    object oBrazier = GetObjectByTag( "BRAZIER" );
    if (!GetIsObjectValid( oBrazier ))
        return sColor;

    string sName = GetLocalString( oBrazier, "TEAM_" + sColor );
    if (sName == "")
        return sColor;

    return sName;
}

// Returns TRUE if both objects belong to the same faction.
int SameTeam( object oTarget, object oMe = OBJECT_SELF )
{
    if (!GetIsObjectValid( oTarget ))
        return FALSE;
    if (!GetIsObjectValid( oMe ))
        return FALSE;
    return GetFactionEqual( oTarget, oMe );
}

// Get a random target waypoint, with a choice between the four altars and the
// doubler.
string GetRandomTarget()
{
    // The next line moves to the spawn location of the similar opponent
    // ActionMoveToLocation( GetLocation( GetObjectByTag( "WP_" + OpponentColor( OBJECT_SELF ) + "_" + IntToString( GetLocalInt( OBJECT_SELF, "INDEX" ) ) ) ), TRUE );

    int iTarget = Random( 5 );

    switch (iTarget)
    {
        case 0:
            return WpDoubler();
            break;

        case 1:
            return WpClosestAltarRight();
            break;

        case 2:
            return WpClosestAltarLeft();
            break;

        case 3:
            return WpFurthestAltarRight();
            break;

        case 4:
            return WpFurthestAltarLeft();
            break;
    }

    return "";
}

// Return the ID of the team with the specified color.
int GetTeamID( string sColor )
{
    object oBrazier = GetObjectByTag( "BRAZIER" );
    if (!GetIsObjectValid( oBrazier ))
        return 1;

    int iTeam = GetLocalInt( oBrazier, "TEAM_" + sColor );
    if (iTeam == 0)
        return 1;

    return iTeam;
}

// Return the tag of the LEFT wizard of the team of oObject, either NPC_BLUE_7 or NPC_RED_7
string TagWizardLeft( object oObject = OBJECT_SELF )
{
    if (!GetIsObjectValid( oObject ))
        return "";
    string sColor = GetLocalString( oObject, "COLOR" );
    if (sColor != COLOR_RED && sColor != COLOR_BLUE)
        return "";
    return "NPC_" + sColor + "_7";
}

// Return the tag of the LEFT cleric of the team of oObject, either NPC_BLUE_6 or NPC_RED_6
string TagClericLeft( object oObject = OBJECT_SELF )
{
    if (!GetIsObjectValid( oObject ))
        return "";
    string sColor = GetLocalString( oObject, "COLOR" );
    if (sColor != COLOR_RED && sColor != COLOR_BLUE)
        return "";
    return "NPC_" + sColor + "_6";
}

// Return the tag of the LEFT fighter of the team of oObject, either NPC_BLUE_5 or NPC_RED_5
string TagFighterLeft( object oObject = OBJECT_SELF )
{
    if (!GetIsObjectValid( oObject ))
        return "";
    string sColor = GetLocalString( oObject, "COLOR" );
    if (sColor != COLOR_RED && sColor != COLOR_BLUE)
        return "";
    return "NPC_" + sColor + "_5";
}

// Return the tag of the master of the team of oObject, either NPC_BLUE_4 or NPC_RED_4
string TagMaster( object oObject = OBJECT_SELF )
{
    if (!GetIsObjectValid( oObject ))
        return "";
    string sColor = GetLocalString( oObject, "COLOR" );
    if (sColor != COLOR_RED && sColor != COLOR_BLUE)
        return "";
    return "NPC_" + sColor + "_4";
}

// Return the tag of the RIGHT fighter of the team of oObject, either NPC_BLUE_3 or NPC_RED_3
string TagFighterRight( object oObject = OBJECT_SELF )
{
    if (!GetIsObjectValid( oObject ))
        return "";
    string sColor = GetLocalString( oObject, "COLOR" );
    if (sColor != COLOR_RED && sColor != COLOR_BLUE)
        return "";
    return "NPC_" + sColor + "_3";
}

// Return the tag of the RIGHT cleric of the team of oObject, either NPC_BLUE_2 or NPC_RED_2
string TagClericRight( object oObject = OBJECT_SELF )
{
    if (!GetIsObjectValid( oObject ))
        return "";
    string sColor = GetLocalString( oObject, "COLOR" );
    if (sColor != COLOR_RED && sColor != COLOR_BLUE)
        return "";
    return "NPC_" + sColor + "_2";
}

// Return the tag of the RIGHT wizard of the team of oObject, either NPC_BLUE_1 or NPC_RED_1
string TagWizardRight( object oObject = OBJECT_SELF )
{
    if (!GetIsObjectValid( oObject ))
        return "";
    string sColor = GetLocalString( oObject, "COLOR" );
    if (sColor != COLOR_RED && sColor != COLOR_BLUE)
        return "";
    return "NPC_" + sColor + "_1";
}

// Returns an indication of the health of oObject.
// 5 = Uninjured (Health = 100% or higher)
// 4 = Slightly injured (Health = 75-100%)
// 3 = Injured (Health = 50-75%)
// 2 = Badly Injured (Health = 25-50%)
// 1 = Near Death (Health = 0-25%)
// 0 = Death (Health = 0%)
int GetHealth( object oObject = OBJECT_SELF )
{
    if (!GetIsObjectValid( oObject ))
        return 0;
    float fRatio = IntToFloat( GetCurrentHitPoints( oObject ) ) / IntToFloat( GetMaxHitPoints( oObject ) );
    if (fRatio >= 1.0)
        return 5;
    else if (fRatio >= 0.75)
        return 4;
    else if (fRatio >= 0.5)
        return 3;
    else if (fRatio >= 0.25)
        return 2;
    else if (fRatio > 0.0)
        return 1;
    else
        return 0;
}

// Returns whether oObject is a wizard
int IsWizard( object oObject = OBJECT_SELF )
{
    if (!GetIsObjectValid( oObject ))
        return FALSE;
    int iIndex = GetLocalInt( oObject, "INDEX" );
    if (iIndex == 1 || iIndex == 7)
        return TRUE;
    return FALSE;
}

// Returns whether oObject is the wizard at the right side
int IsWizardRight( object oObject = OBJECT_SELF )
{
    if (!GetIsObjectValid( oObject ))
        return FALSE;
    int iIndex = GetLocalInt( oObject, "INDEX" );
    if (iIndex == 1)
        return TRUE;
    return FALSE;
}

// Returns whether oObject is the wizard at the left side
int IsWizardLeft( object oObject = OBJECT_SELF )
{
    if (!GetIsObjectValid( oObject ))
        return FALSE;
    int iIndex = GetLocalInt( oObject, "INDEX" );
    if (iIndex == 7)
        return TRUE;
    return FALSE;
}

// Returns whether oObject is a cleric
int IsCleric( object oObject = OBJECT_SELF )
{
    if (!GetIsObjectValid( oObject ))
        return FALSE;
    int iIndex = GetLocalInt( oObject, "INDEX" );
    if (iIndex == 2 || iIndex == 6)
        return TRUE;
    return FALSE;
}

// Returns whether oObject is the cleric at the right side
int IsClericRight( object oObject = OBJECT_SELF )
{
    if (!GetIsObjectValid( oObject ))
        return FALSE;
    int iIndex = GetLocalInt( oObject, "INDEX" );
    if (iIndex == 2)
        return TRUE;
    return FALSE;
}

// Returns whether oObject is the cleric at the left side
int IsClericLeft( object oObject = OBJECT_SELF )
{
    if (!GetIsObjectValid( oObject ))
        return FALSE;
    int iIndex = GetLocalInt( oObject, "INDEX" );
    if (iIndex == 6)
        return TRUE;
    return FALSE;
}

// Returns whether oObject is a fighter
int IsFighter( object oObject = OBJECT_SELF )
{
    if (!GetIsObjectValid( oObject ))
        return FALSE;
    int iIndex = GetLocalInt( oObject, "INDEX" );
    if (iIndex == 3 || iIndex == 5)
        return TRUE;
    return FALSE;
}

// Returns whether oObject is the fighter at the right side
int IsFighterRight( object oObject = OBJECT_SELF )
{
    if (!GetIsObjectValid( oObject ))
        return FALSE;
    int iIndex = GetLocalInt( oObject, "INDEX" );
    if (iIndex == 3)
        return TRUE;
    return FALSE;
}

// Returns whether oObject is the fighter at the left side
int IsFighterLeft( object oObject = OBJECT_SELF )
{
    if (!GetIsObjectValid( oObject ))
        return FALSE;
    int iIndex = GetLocalInt( oObject, "INDEX" );
    if (iIndex == 5)
        return TRUE;
    return FALSE;
}

// Returns whether oObject is a master
int IsMaster( object oObject = OBJECT_SELF )
{
    if (!GetIsObjectValid( oObject ))
        return FALSE;
    int iIndex = GetLocalInt( oObject, "INDEX" );
    if (iIndex == 4)
        return TRUE;
    return FALSE;
}

