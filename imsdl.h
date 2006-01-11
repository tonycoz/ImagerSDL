#ifndef IMAGER_SDL_IMSDL_H
#define IMAGER_SDL_IMSDL_H

#include <SDL.h>

extern i_img *
i_img_sdl_new(SDL_Surface *surface, int auto_update);

extern void
i_sdl_auto_lock(i_img *im, int auto_update);

extern void
i_sdl_update(i_img *im);

#endif
