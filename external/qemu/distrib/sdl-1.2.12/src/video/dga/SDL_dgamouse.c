
#include "SDL_config.h"

#include <stdio.h>

#include "SDL_mouse.h"
#include "../../events/SDL_events_c.h"
#include "SDL_dgavideo.h"
#include "SDL_dgamouse_c.h"


/* The implementation dependent data for the window manager cursor */
struct WMcursor {
	int unused;
};
