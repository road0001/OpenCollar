////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                                 occ_slave_cuff                                 //
//                                 version 7.1035                                 //
// ------------------------------------------------------------------------------ //
// Licensed under the GPLv2 with additional requirements specific to Second Life® //
// and other virtual metaverse environments.                                      //
// ------------------------------------------------------------------------------ //
// ©   2008 - 2013  Individual Contributors and OpenCollar - submission set free™ //
// ©   2013 - 2018  OpenNC North Glenwalker                                       //
// ©   2018 -       OpenCollar North Glenwalker                                   //
//      Suport for Arms, Legs, Wings, and Tail cuffs and restrictions             //
////////////////////////////////////////////////////////////////////////////////////

// change here for OS and IW grids
// Do not change anything behond here

string    g_szModToken    = "llac"; // valid token for this module, TBD need to be read more global
key g_keyWearer = NULL_KEY;  // key of the owner/wearer
// Messages to be received
string g_szLockCmd="Lock"; // message for setting lock on or off
string g_szInfoRequest="SendLockInfo"; // request info about RLV and Lock status from main cuff

// name of occ part for requesting info from the master cuff
// NOTE: for products other than cuffs this HAS to be change for the OCC names or the your items will interferre with the cuffs
list lstCuffNames=["Not","chest","skull","lshoulder","rshoulder","lhand","rhand","lfoot","rfoot","spine","ocbelt","mouth","chin","lear","rear","leye","reye","nose","ruac","rlac","luac","llac","rhip","rulc","rllc","lhip","lulc","lllc","ocbelt","rpec","lpec","HUD Center 2","HUD Top Right","HUD Top","HUD Top Left","HUD Center","HUD Bottom Left","HUD Bottom","HUD Bottom Right"];

integer g_nLocked=FALSE; // is the cuff locked
integer g_nUseRLV=FALSE; // should RLV be used
integer g_nLockedState=FALSE; // state submitted to RLV viewer
string g_szIllegalDetach="";
key g_keyFirstOwner;
integer listener;
integer g_nCmdChannel    = -190890;
integer g_nCmdHandle    = 0;            // command listen handler
integer g_nCmdChannelOffset = 0xCC0CC;       // offset to be used to make sure we do not interfere with other items using the same technique for
integer LM_CHAIN_CMD = -551001;
integer LM_CUFF_CUFFPOINTNAME = -551003;
//apperance
string g_szColorChangeCmd="ColorChanged";
string g_szTextureChangeCmd="TextureChanged";
string g_szHideCmd="HideMe"; // Comand for Cuffs to hide
integer g_nHidden=FALSE;
list TextureElements;
list ColorElements;
list textures;
list colorsettings;
list g_lAlphaSettings;
string g_sIgnore = "nohide";
//end
//_slave
//string  g_szAllowedCommadToken = "rlac"; // only accept commands from this token adress
list    g_lstModTokens    = []; // valid token for this module
integer    CMD_UNKNOWN        = -1;        // unknown command - don't handle
integer    CMD_CHAT        = 0;        // chat cmd - check what should happen with it
integer    CMD_EXTERNAL    = 1;        // external cmd - check what should happen with it
integer    CMD_MODULE        = 2;        // cmd for this module
integer    g_nCmdType        = CMD_UNKNOWN;
//
// external command syntax
// sender prefix|receiver prefix|command1=value1~command2=value2|UUID to send under
// occ|rwc|chain=on~lock=on|aaa-bbb-2222...
//
string    g_szReceiver    = "";
string    g_szSender        = "";
//end

//size adust
float MIN_DIMENSION=0.01; // the minimum scale of a root prim allowed, in any dimension
float MAX_DIMENSION=0.25; // the maximum scale of a root prim allowed, in any dimension
float max_scale;
float min_scale;
float   cur_scale = 1.0;
integer handle;
integer menuChan;
float start_size;

makeMenu()
{
    llDialog(llGetOwner(),"Max scale: "+(string)max_scale+"\nMin scale: "+(string)min_scale+"\n \nCurrent scale: "+
        (string)cur_scale,["-0.01","-0.05","MIN SIZE","+0.01","+0.05","MAX SIZE","-0.10","-0.25","RESTORE","+0.10","+0.25"],menuChan);
}

saveStartScale()
{
    vector vSize = llGetScale();
    start_size = vSize.x;
    max_scale = MAX_DIMENSION/start_size;
    min_scale = MIN_DIMENSION/start_size;
}

resizeObject(float scale)
{
    vector vSize = llGetScale();

    // calculate scaling factor
    float scaling_factor = start_size * scale / vSize.x ;

    // get a float that is the smallest scaling factor that can be used with llScaleByFactor to resize the object.
    float min_scale_factor = llGetMinScaleFactor();

    // compare scaling factor and smallest scaling factor
    if (scaling_factor < min_scale_factor) scaling_factor = min_scale_factor;

    // use new scale function integer llScaleByFactor( float scaling_factor );
    // http://wiki.secondlife.com/wiki/LlScaleByFactor
    llScaleByFactor(scaling_factor);
}
//end of size adjust

SendCmd( string szSendTo, string szCmd, key keyID ) //this is not the same format as SendCmd1
{
    llRegionSay(g_nCmdChannel, g_szModToken + "|" + szSendTo + "|" + szCmd + "|" + (string)keyID);
}

SendCmd1( string szSendTo, string szCmd, key keyID )
{
    llRegionSay(g_nCmdChannel, llList2String(g_lstModTokens,0) + "|" + szSendTo + "|" + szCmd + "|" + (string)keyID);
}

integer nGetOwnerChannel(integer nOffset)
{
    integer chan = (integer)("0x"+llGetSubString((string)g_keyWearer,3,8)) + g_nCmdChannelOffset;
    if (chan>0)
        chan=chan*(-1);
    if (chan > -10000)
        chan -= 30000;
    return chan;
}

integer nStartsWith(string szHaystack, string szNeedle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return (llDeleteSubString(szHaystack, llStringLength(szNeedle), -1) == szNeedle);
}

SetLocking()
{
    if (g_nLocked)
    {// lock or unlock cuff as needed in RLV
        if ((!g_nLockedState && g_nUseRLV) || (g_nLockedState && g_nUseRLV))
        {
            g_nLockedState=TRUE;
            llOwnerSay("@detach=n");
        }
        else if (g_nLockedState && !g_nUseRLV)
            llOwnerSay("@detach=y");
    }
    else
    {
        if (g_nLockedState)
            g_nLockedState=FALSE;
        llOwnerSay("@detach=y");
    }
}

string GetCuffName()
{
    return llList2String(lstCuffNames,llGetAttached());
}
//Theames

list commands = ["themes", "hide", "show", "stealth", "color", "texture", "shiny", "glow", "looks"];
string g_sDeviceType = "cuff";
integer g_iCollarHidden;
list g_lGlows;
list g_lShiny = ["none","low","medium","high","specular"];
list g_lShinyDefaults;
list g_lGlow = ["none",0.0,"low",0.1,"medium",0.2,"high",0.4,"veryHigh",0.8];
list g_lTextureDefaults;
list g_lTextures;
list g_lTextureKeys;
list g_lHideDefaults;
list g_lColorDefaults;

string LinkType(integer iLinkNum, string sSearchString) {
    string sDesc = llList2String(llGetLinkPrimitiveParams(iLinkNum, [PRIM_DESC]),0);
    //prim desc will be elementtype~notexture(maybe)
    list lParams = llParseString2List(llStringTrim(sDesc,STRING_TRIM), ["~"], []);

    if (~llListFindList(lParams,[sSearchString])) return "immutable";
    else if (sDesc == "" || sDesc == "(No Description)") return "";
    else return llList2String(lParams, 0);
}

UserCommand(string sStr, key kID) {
    list lParams = llParseString2List(sStr, [" "], []);
    string sCommand=llToLower(llList2String(lParams,0));
    string sElement=llList2String(lParams,1);
    if (sCommand == "hide" || sCommand == "show" || sCommand == "stealth") {
        //get currently shown state
        integer iCurrentlyShown;
        if (sElement=="") sElement=g_sDeviceType;
        if (sCommand == "show")       iCurrentlyShown = 1;
        else if (sCommand == "hide")  iCurrentlyShown = 0;
        else if (sCommand == "stealth") iCurrentlyShown = g_iCollarHidden;
        if (sElement == g_sDeviceType) g_iCollarHidden = !iCurrentlyShown;  //toggle whole collar visibility

        //do the actual hiding and re/de-glowing of elements
        integer iLinkCount = llGetNumberOfPrims()+1;
        while (iLinkCount-- > 1) {
            string sLinkType=LinkType(iLinkCount, "nohide");
            if (sLinkType == sElement || sElement==g_sDeviceType) {
                if (!g_iCollarHidden || sElement == g_sDeviceType ) {
                    //don't change things if collar is set hidden, unless we're doing the hiding now
                    llSetLinkAlpha(iLinkCount,(float)(iCurrentlyShown),ALL_SIDES);
                    //update glow settings for this link
                    integer iGlowsIndex = llListFindList(g_lGlows,[iLinkCount]);
                    if (iCurrentlyShown){  //restore glow if it is now shown
                        if (~iGlowsIndex) {  //if it had a glow, restore it, otherwise don't
                            float fGlow = (float)llList2String(g_lGlows, iGlowsIndex+1);
                            llSetLinkPrimitiveParamsFast(iLinkCount, [PRIM_GLOW, ALL_SIDES, fGlow]);
                        }
                    } else {  //save glow and switch it off if it is now hidden
                        float fGlow = llList2Float(llGetLinkPrimitiveParams(iLinkCount,[PRIM_GLOW,0]),0) ;
                        if (fGlow > 0) {  //if it glows, store glow
                            if (~iGlowsIndex) g_lGlows = llListReplaceList(g_lGlows,[fGlow],iGlowsIndex+1,iGlowsIndex+1) ;
                            else g_lGlows += [iLinkCount, fGlow];
                        } else if (~iGlowsIndex) g_lGlows = llDeleteSubList(g_lGlows,iGlowsIndex,iGlowsIndex+1); //remove glow from list
                        llSetLinkPrimitiveParamsFast(iLinkCount, [PRIM_GLOW, ALL_SIDES, 0.0]);  // set no glow;
                    }
                }
            }
        }
    } else if (sCommand == "shiny") {
        string sShiny=llList2String(lParams,2);
        integer iShinyIndex=llListFindList(g_lShiny,[sShiny]);
        if (~iShinyIndex) sShiny=(string)iShinyIndex;  //if found, convert string to index and overwrite supplied string
        integer iShiny=(integer)sShiny;  //cast string to integer, we now have the index, or 0 for a bad value

        if (iShiny || sShiny=="0") {  //if we have a value, or if 0 was passed in as a string value
            integer iLinkCount = llGetNumberOfPrims()+1;
            while (iLinkCount-- > 2) {
                string sLinkType=LinkType(iLinkCount, "no"+sCommand);
                if (sLinkType == sElement || (sLinkType != "immutable" && sLinkType != "" && sElement=="ALL")) {
                    if (iShiny < 4 )
                        llSetLinkPrimitiveParamsFast(iLinkCount,[PRIM_SPECULAR,ALL_SIDES,(string)NULL_KEY, <1,1,0>,<0,0,0>,0.0,<1,1,1>,0,0,PRIM_BUMP_SHINY,ALL_SIDES,iShiny,0]);
                    else
                        llSetLinkPrimitiveParamsFast(iLinkCount,[PRIM_SPECULAR,ALL_SIDES,(string)TEXTURE_BLANK, <1,1,0>,<0,0,0>,0.0,<1,1,1>,80,2]);
                }
            }
        }
    }
    else if (sCommand == "glow") {
        string sGlow=llList2String(lParams,2);
        integer iGlowIndex=llListFindList(g_lGlow,[sGlow]);
        float fGlow = (float)sGlow;
        if (~iGlowIndex) {
            sGlow=(string)llList2String(g_lGlow,iGlowIndex+1);//if found, convert string to index and overwrite supplied string
            fGlow = llList2Float(g_lGlow,iGlowIndex+1);   //cast string to float, we now have the index, or 0 for a bad value
        }
        else if ((fGlow >= 0.0 && fGlow <= 1.0)|| sGlow=="0") {  //if we have a value, or if 0 was passed in as a string value
            integer iLinkCount = llGetNumberOfPrims()+1;
            while (iLinkCount-- > 2) {
                string sLinkType=LinkType(iLinkCount, "no"+sCommand);
                if (sLinkType == sElement || (sLinkType != "immutable" && sLinkType != "" && sElement=="ALL"))
                    llSetLinkPrimitiveParamsFast(iLinkCount,[PRIM_GLOW,ALL_SIDES,fGlow]);
            }
        }
    } else if (sCommand == "color") {
        string sColor = llDumpList2String(llDeleteSubList(lParams,0,1)," ");
        if (sColor != "") {
            integer iLinkCount = llGetNumberOfPrims()+1;
            vector vColorValue=(vector)sColor;
            while (iLinkCount-- > 1) {
                string sLinkType=LinkType(iLinkCount, "nocolor");
                if (sLinkType == sElement || (sLinkType != "immutable" && sLinkType != "" && sElement=="ALL")) {//llOwnerSay((string) iLinkCount + " " + sStr);
                    llSetLinkColor(iLinkCount, vColorValue, ALL_SIDES);  //set link to new color
                }
            }
        }
    } else if (sCommand=="texture") {
        string sTextureShortName=llDumpList2String(llDeleteSubList(lParams,0,1)," ");
        if (sTextureShortName=="Default") {  //if we have one, set the default texture for this element type, else error and give texture menu
            integer iDefaultTextureIndex = llListFindList(g_lTextureDefaults, [sElement]);
            if (~iDefaultTextureIndex) sTextureShortName=llList2String(g_lTextureDefaults, iDefaultTextureIndex + 1);
        }
        //get long name from short name
        integer iTextureIndex=llListFindList(g_lTextures,[sElement+"~"+sTextureShortName]);  //first try to get index of custom texture
        if ((key)sTextureShortName) iTextureIndex=0;  //we have been given a key, so pretend we found it in the list
        else if (! ~iTextureIndex) {
            iTextureIndex=llListFindList(g_lTextures,[sTextureShortName]);  //else get index of regular texture
        }

        if (! ~iTextureIndex) {  //invalid texture name supplied, send texture menu for this element
        } else {  //valid element and texture names supplied, apply texture
            //get key from long name
            string sTextureKey;
            if ((key)sTextureShortName) sTextureKey=sTextureShortName;
            else sTextureKey=llList2String(g_lTextureKeys,iTextureIndex);
            //loop through prims and apply texture key
            integer iLinkCount = llGetNumberOfPrims()+1;
            while (iLinkCount-- > 2) {
                string sLinkType=LinkType(iLinkCount, "notexture");
                if (sLinkType == sElement || (sLinkType != "immutable" && sLinkType != "" && sElement=="ALL")) {
                    //Debug("Applying texture to element number "+(string)iLinkCount);
                    // update prim texture for each face with save texture repeats, offsets and rotations
                    integer iSides = llGetLinkNumberOfSides(iLinkCount);
                    integer iFace ;
                    for (iFace = 0; iFace < iSides; iFace++) {
                        list lPrimParams = llGetLinkPrimitiveParams(iLinkCount, [PRIM_TEXTURE, iFace ]);
                        lPrimParams = llDeleteSubList(lPrimParams,0,0); // get texture params **** error on this line called lPrim not lPrimParams

                        llSetLinkPrimitiveParamsFast(iLinkCount, [PRIM_TEXTURE, iFace, sTextureKey]+lPrimParams);
                    }
                }
            }
        }
    }
}

integer IsAllowed( key keyID )
{
    integer nAllow = FALSE;

    if ( llGetOwnerKey(keyID) == g_keyWearer )
        nAllow = TRUE;
    return nAllow;
}

string CheckCmd( key keyID, string szMsg )
{
    list lstParsed = llParseString2List( szMsg, [ "|" ], [] );
    string szCmd = szMsg;
    // first part should be sender token
    // second part the receiver token
    // third part = command
    if ( llGetListLength(lstParsed) > 2 )
    {
        // check the sender of the command occ,rwc,...
        g_szSender = llList2String(lstParsed,0);
        g_nCmdType = CMD_UNKNOWN;
        g_nCmdType = CMD_EXTERNAL;
        // cap and store the receiver
        g_szReceiver = llList2String(lstParsed,1);
        // we are the receiver
        if ( (llListFindList(g_lstModTokens,[g_szReceiver]) != -1) || g_szReceiver == "*" )
        {
            // set cmd return to the rest of the command string
            szCmd = llList2String(lstParsed,2);
            g_nCmdType = CMD_MODULE;
        }
    }
    lstParsed = [];
    return szCmd;
}

ParseCmdString( key keyID, string szMsg )
{
    list    lstParsed = llParseString2List( szMsg, [ "~" ], [] );
    integer nCnt = llGetListLength(lstParsed);
    integer i = 0;
    for (i = 0; i < nCnt; i++ )
        ParseSingleCmd(keyID, llList2String(lstParsed, i));
    lstParsed = [];
}

ParseSingleCmd( key keyID, string szMsg )
{
    list    lstParsed    = llParseString2List( szMsg, [ "=" ], [] );
    string    szCmd    = llList2String(lstParsed,0);
    string    szValue    = llList2String(lstParsed,1);
    if ( szCmd == "chain" )
    {
        if (( llGetListLength(lstParsed) == 4 )||( llGetListLength(lstParsed) == 7 ))
        {
            if ( llGetKey() != keyID )
                llMessageLinked( LINK_SET, LM_CHAIN_CMD, szMsg, llGetKey() );
        }
    }
    else
        LM_CUFF_CMD(szMsg, keyID);
    lstParsed = [];
}

LM_CUFF_CMD(string szMsg, key id)
{// message for cuff received;
    // or info about RLV to be used
//    llOwnerSay(szMsg);
    if (nStartsWith(szMsg,g_szLockCmd))
    {// it is a lock commans
        list lstCmdList    = llParseString2List( szMsg, [ "=" ], [] );
        if (llList2String(lstCmdList,1)=="on")
            g_nLocked=TRUE;
        else
            g_nLocked=FALSE;
        // Update Cuff lock status
        SetLocking();
    }
    else if (szMsg == "rlvon")
    {// RLV got activated
        g_nUseRLV=TRUE;
        // Update Cuff lock status
        SetLocking();
    }
    else if (szMsg == "rlvoff")
    {// RLV got deactivated
        g_nUseRLV=FALSE;
        // Update Cuff lock status
        SetLocking();
    }
    //apperance
    //rebuild to new themes
    list lParams = llParseString2List(szMsg, ["="], []);
    string sID = llList2String(lParams, 0);
    string sValue = llList2String(lParams, 1);
    integer i = llSubStringIndex(sID, "_");
    string sCategory=llGetSubString(sID, 0, i);
    string sToken = llGetSubString(sID, i + 1, -1);
    if (sCategory == "texture_") {
        i = llListFindList(g_lTextureDefaults, [sToken]);
        if (~i) g_lTextureDefaults = llListReplaceList(g_lTextureDefaults, [sValue], i + 1, i + 1);
        else g_lTextureDefaults += [sToken, sValue];
    }
    else if (sCategory == "shiny_") {
        i = llListFindList(g_lShinyDefaults, [sToken]);
        if (~i) g_lShinyDefaults = llListReplaceList(g_lShinyDefaults, [sValue], i + 1, i + 1);
        else g_lShinyDefaults += [sToken, sValue];
    }
    else if (sCategory == "hide_") {
        i = llListFindList(g_lHideDefaults, [sToken]);
        if (~i) g_lHideDefaults = llListReplaceList(g_lHideDefaults, [sValue], i + 1, i + 1);
        else g_lHideDefaults += [sToken, sValue];
    }
    else if (sCategory == "color_") {
        i = llListFindList(g_lColorDefaults, [sToken]);
        if (~i) g_lColorDefaults = llListReplaceList(g_lColorDefaults, [sValue], i + 1, i + 1);
        else g_lColorDefaults += [sToken, sValue];
    }
    UserCommand( llList2String(llParseString2List(sID, ["_"], []),0) + " " + llList2String(llParseString2List(sID, ["_"], []),1) +" "+sValue, id);//NG added
}

string Float2String(float in)
{
    string out = (string)in;
    integer i = llSubStringIndex(out, ".");
    while (~i && llStringLength(llGetSubString(out, i + 2, -1)) && llGetSubString(out, -1, -1) == "0")
        out = llGetSubString(out, 0, -2);
    return out;
}
string ElementType(integer linkiNumber)
{
    string sDesc = (string)llGetObjectDetails(llGetLinkKey(linkiNumber), [OBJECT_DESC]);
    //each prim should have <elementname> in its description, plus "nocolor" or "notexture", if you want the prim to  not appear in the color or texture menus
    list lParams = llParseString2List(sDesc, ["~"], []);
    if ((~(integer)llListFindList(lParams, [g_sIgnore])) || sDesc == "" || sDesc == " " || sDesc == "(No Description)")
        return g_sIgnore;
    else
        return llList2String(lParams, 0);
}

Init()
{
    g_keyWearer = llGetOwner();
    // get unique channel numbers for the command and cuff channel, cuff channel wil be used for LG chains of cuffs as well
    g_nCmdChannel = nGetOwnerChannel(g_nCmdChannelOffset);
    llListenRemove(g_nCmdHandle);
    g_nCmdHandle = llListen(g_nCmdChannel + 1, "", NULL_KEY, "");
    g_lstModTokens = (list)llList2String(lstCuffNames,llGetAttached()); // get name of the cuff from the attachment point, this is absolutly needed for the system to work, other chain point wil be received via LMs
    g_szModToken=GetCuffName();
    SendCmd("rlac",g_szInfoRequest,g_keyWearer); // request infos from main cuff
    SetLocking(); // and set all existing lockstates now
}

default
{
    state_entry()
    {
        Init();
        saveStartScale();
    }

    on_rez(integer param)
    {
        if (llGetAttached() == 0) // If not attached then
        {
            llResetScript();
            return;
        }

        if (g_keyWearer == llGetOwner())
        {
            Init();// we keep loosing who we are so main cuff won't hear us
            if (g_nLockedState)
                llOwnerSay("@detach=n");
        }
        else llResetScript();
    }

    touch_start(integer nCnt)
    {
        //resize
        llListenRemove(handle);
        menuChan = 50000 + (integer)llFrand(50000.00);
        handle = llListen(menuChan,"",llGetOwner(),"");
        llSetTimerEvent(60);
        key id = llDetectedKey(0);
        if ((llGetAttached() == 0)&& (id==g_keyWearer)) // If not attached then wake up update script then do nothing
        {
            llSetScriptState("occ_update",TRUE);
            return;
        }

        if (llDetectedKey(0) == llGetOwner())// if we are wearer then allow to resize
            llDialog(llGetOwner(),"Select if you want to Resize this item or the main Cuff Menu ",["Resizer","Cuff Menu"],menuChan);
        // else just ask for main cuff menu
        else { SendCmd1("rlac", "cmenu=on="+(string)llDetectedKey(0), llDetectedKey(0));}
    }

    listen(integer nChannel, string szName, key keyID, string szMsg)
    {
        szMsg = llStringTrim(szMsg, STRING_TRIM);
        // commands sent on cmd channel
        if ( nChannel == g_nCmdChannel+ 1 )
        {
            if ( IsAllowed(keyID) )
            {
                if (llGetSubString(szMsg,0,8)=="lockguard") // this should not be happening!
                    llMessageLinked(LINK_SET, -9119, szMsg, keyID);
                else
                { // check if external or maybe for this module
                    string szCmd = CheckCmd( keyID, szMsg );
                    if ( g_nCmdType == CMD_MODULE )
                        ParseCmdString(keyID, szCmd);
                }
            }
        }
        else if (keyID == llGetOwner())
        {
            if (szMsg == "Cuff Menu")
                SendCmd1("rlac", "cmenu=on="+(string)keyID, keyID);
            else if (szMsg == "Resizer")
                makeMenu();
            else
            {
                if (szMsg == "RESTORE")
                    cur_scale = 1.0;
                else if (szMsg == "MIN SIZE")
                    cur_scale = min_scale;
                else if (szMsg == "MAX SIZE")
                    cur_scale = max_scale;
                else
                    cur_scale += (float)szMsg;
                //check that the scale doesn't go beyond the bounds
                if (cur_scale > max_scale)
                    cur_scale = max_scale;
                if (cur_scale < min_scale)
                    cur_scale = min_scale;
                resizeObject(cur_scale);
                makeMenu();
            }
        }
    }

    timer()
    {
        //Clear resize menu listen
        llSetTimerEvent(0);
        llListenRemove(handle);
    }
}
