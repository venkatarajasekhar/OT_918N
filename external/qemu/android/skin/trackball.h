
#ifndef _ANDROID_SKIN_TRACKBALL_H
#define _ANDROID_SKIN_TRACKBALL_H

#include <SDL.h>
#include "android/skin/rect.h"

typedef struct SkinTrackBall  SkinTrackBall;

typedef struct SkinTrackBallParameters
{
    int       diameter;
    int       ring;
    unsigned  ball_color;
    unsigned  dot_color;
    unsigned  ring_color;
}
SkinTrackBallParameters;


extern SkinTrackBall*  skin_trackball_create  ( SkinTrackBallParameters*  params );
extern void            skin_trackball_rect    ( SkinTrackBall*  ball, SDL_Rect*  rect );
extern int             skin_trackball_contains( SkinTrackBall*  ball, int  x, int  y );
extern int             skin_trackball_move    ( SkinTrackBall*  ball, int  dx, int  dy );
extern void            skin_trackball_refresh ( SkinTrackBall*  ball );
extern void            skin_trackball_draw    ( SkinTrackBall*  ball, int  x, int  y, SDL_Surface*  dst );
extern void            skin_trackball_destroy ( SkinTrackBall*  ball );

/* this sets the rotation that will be applied to mouse events sent to the system */
extern void            skin_trackball_set_rotation( SkinTrackBall*  ball, SkinRotation  rotation);

#endif /* END */

