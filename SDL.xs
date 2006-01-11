#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#ifdef __cplusplus
}
#endif

#include "imext.h"
#include "imperl.h"
#include "imsdl.h"

DEFINE_IMAGER_CALLBACKS;


MODULE = Imager::SDL   PACKAGE = Imager::SDL

PROTOTYPES: ENABLE

Imager::ImgRaw
i_img_sdl_new(surface, auto_update)
        SDL_Surface *surface
        int auto_update

void
i_sdl_auto_lock(im, auto_lock)
        Imager::ImgRaw im
        int auto_lock

void
i_sdl_update(im)
        Imager::ImgRaw im


BOOT:
        PERL_INITIALIZE_IMAGER_CALLBACKS;

