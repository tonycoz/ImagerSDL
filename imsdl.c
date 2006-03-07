#include "imext.h"
#include "imsdl.h"
#include <string.h>
#include <limits.h>

/* define this to enable smart updates */
#define SMART_UPDATES

typedef struct {
  SDL_Surface *surface;
  int auto_lock;
  int auto_update;

#ifdef SMART_UPDATES
  /* saved rectangle to update */
  int left, top, right, bottom;
#endif
} imsdl_ext;

typedef void (*sdl_set_func)(SDL_Surface *, int l, int r, int y, const i_color *col);
typedef void (*sdl_get_func)(SDL_Surface *, int l, int r, int y, i_color *col);

/* for now */
static void general_getter(SDL_Surface *, int l, int r, int y, i_color *);
static void general_setter(SDL_Surface *, int l, int r, int y, const i_color *);

#define get_getter(surface) general_getter
#define get_setter(surface) general_setter

#define ext(im) ((imsdl_ext *)((im)->ext_data))
#define AUTO_LOCK(im) (ext(im)->auto_lock)
#define DO_AUTO_LOCK(im) if (ext(im)->auto_lock) SDL_LockSurface(IMSURFACE(im))
#define DO_AUTO_UNLOCK(im) if (ext(im)->auto_lock) SDL_UnlockSurface(IMSURFACE(im))
#define IMSURFACE(im) (ext(im)->surface)

#define SampleFTo8(num) ((int)((num) * 255.0 + 0.01))
#define Sample8ToF(num) ((num) / 255.0)

static int i_ppix_sdl_d(i_img *im, int x, int y, const i_color *val);
static int i_gpix_sdl_d(i_img *im, int x, int y, i_color *val);
static int i_glin_sdl_d(i_img *im, int l, int r, int y, i_color *vals);
static int i_plin_sdl_d(i_img *im, int l, int r, int y, const i_color *vals);
static int i_ppixf_sdl_d(i_img *im, int x, int y, const i_fcolor *val);
static int i_gpixf_sdl_d(i_img *im, int x, int y, i_fcolor *val);
static int i_glinf_sdl_d(i_img *im, int l, int r, int y, i_fcolor *vals);
static int i_plinf_sdl_d(i_img *im, int l, int r, int y, const i_fcolor *vals);
static int i_gsamp_sdl_d(i_img *im, int l, int r, int y, i_sample_t *samps, const int *chans, int chan_count);
static int i_gsampf_sdl_d(i_img *im, int l, int r, int y, i_fsample_t *samps, const int *chans, int chan_count);
static void i_destroy_sdl_d(i_img *im);
static void freshen_update(imsdl_ext *ext, int l, int r, int y);

static i_img base_sdl_img =
{
  0, /* channels set */
  0, 0, 0, /* xsize, ysize, bytes */
  ~0U, /* ch_mask */
  i_8_bits, /* bits */
  i_direct_type, /* type */
  1, /* virtual */
  NULL, /* idata */
  { 0, 0, NULL }, /* tags */
  NULL, /* ext_data */

  i_ppix_sdl_d, /* i_f_ppix */
  i_ppixf_sdl_d, /* i_f_ppixf */
  i_plin_sdl_d, /* i_f_plin */
  i_plinf_sdl_d, /* i_f_plinf */
  i_gpix_sdl_d, /* i_f_gpix */
  i_gpixf_sdl_d, /* i_f_gpixf */
  i_glin_sdl_d, /* i_f_glin */
  i_glinf_sdl_d, /* i_f_glinf */
  i_gsamp_sdl_d, /* i_f_gsamp */
  i_gsampf_sdl_d, /* i_f_gsampf */

  NULL, /* i_f_gpal */
  NULL, /* i_f_ppal */
  NULL, /* i_f_addcolors */
  NULL, /* i_f_getcolors */
  NULL, /* i_f_colorcount */
  NULL, /* i_f_maxcolors */
  NULL, /* i_f_findcolor */
  NULL, /* i_f_setcolors */

  i_destroy_sdl_d, /* i_f_destroy */
};

i_img *
i_img_sdl_new(SDL_Surface *surface, int auto_update) {
  i_img *im;

  i_clear_error();

  if (!surface) {
    i_push_error(0, "NULL surface handle supplied");
    return NULL;
  }

  /* for now we only support direct color */
  if (surface->format->BytesPerPixel == 1) {
    i_push_error(0, "Only direct color surfaces supported");
    return NULL;
  }

  im = mymalloc(sizeof(i_img));

  memcpy(im, &base_sdl_img, sizeof(i_img));
  im->xsize = surface->w;
  im->ysize = surface->h;
  im->channels = 3;
  im->bytes = 0;
  im->ext_data = mymalloc(sizeof(imsdl_ext));
  ext(im)->surface = surface;
  ext(im)->auto_lock = SDL_MUSTLOCK(surface);
  ext(im)->auto_update = 0;
#ifdef SMART_UPDATES
  ext(im)->left = ext(im)->top = ext(im)->right = ext(im)->bottom = -1;
#endif
  i_tags_new(&im->tags);

  return im;
}

void
i_sdl_auto_lock(i_img *im, int auto_lock) {
  ext(im)->auto_lock = SDL_MUSTLOCK(IMSURFACE(im)) && auto_lock;
}

void
i_sdl_update(i_img *im) {
  imsdl_ext *ext = ext(im);

#ifdef SMART_UPDATES
  if (ext->left == -1)
    return;

#if 0
  printf("surf %p x %d y %d w %d h %d\n", ext->surface, ext->left, ext->top, ext->right - ext->left, 
                 ext->bottom - ext->top + 1);
#endif

  SDL_UpdateRect(ext->surface, ext->left, ext->top, ext->right - ext->left, 
                 ext->bottom - ext->top + 1);
  ext->left = -1;
#else
  /* stupid updates */
  /*SDL_UpdateRects(ext->surface, 0, NULL); */
  printf("surf %p\n", ext->surface);
  printf("pixels %p hwdata %p map %p\n", ext->surface->pixels, ext->surface->hwdata, ext->surface->map);
  SDL_UpdateRect(ext->surface, 0, 0, 0, 0);
#endif
}

static int
i_ppix_sdl_d(i_img *im, int x, int y, const i_color *val) {
  return i_plin_sdl_d(im, x, x+1, y, val) ? -1 : 0;
}

static int 
i_gpix_sdl_d(i_img *im, int x, int y, i_color *val) {
  return i_glin_sdl_d(im, x, x+1, y, val) ? 0 : -1;
}

static int
i_glin_sdl_d(i_img *im, int l, int r, int y, i_color *vals) {
  int count = 0;
  SDL_Surface *surface = IMSURFACE(im);
  sdl_get_func getter;

  if (l < 0 || l >= im->xsize)
    return 0;
  if (y < 0 || y >= im->ysize)
    return 0;

  if (r >= im->xsize)
    r = im->xsize;

  if (r <= l)
    return 0;

  count = r - l;

  DO_AUTO_LOCK(im);

  getter = get_getter(surface);
  getter(surface, l, r, y, vals);

  DO_AUTO_UNLOCK(im);

  count;
}

static int
i_plin_sdl_d(i_img *im, int l, int r, int y, const i_color *vals) {
  int count = 0;
  SDL_Surface *surface = IMSURFACE(im);
  sdl_set_func setter;

  if (l < 0 || l >= im->xsize)
    return 0;
  if (y < 0 || y >= im->ysize)
    return 0;

  if (r >= im->xsize)
    r = im->xsize;

  if (r <= l)
    return 0;

  count = r - l;

  DO_AUTO_LOCK(im);

  setter = get_setter(surface);
  setter(surface, l, r, y, vals);

  DO_AUTO_UNLOCK(im);

  if (ext(im)->auto_update)
    SDL_UpdateRect(IMSURFACE(im), l, r-l, y, 1);
  else
    freshen_update(ext(im), l, r, y);

  return count;
}

static int 
i_gsamp_sdl_d(i_img *im, int l, int r, int y, i_sample_t *samps, const int *chans, int chan_count) {
  int count = 0;
  SDL_Surface *surface = IMSURFACE(im);
  sdl_get_func getter;
  int i, w, ch;

  if (l < 0 || l >= im->xsize)
    return 0;
  if (y < 0 || y >= im->ysize)
    return 0;

  if (r >= im->xsize)
    r = im->xsize;

  if (r <= l)
    return 0;

  DO_AUTO_LOCK(im);

  getter = get_getter(surface);
  w = r - l;
  if (chans) {
    /* make sure we have good channel numbers */
    for (ch = 0; ch < chan_count; ++ch) {
      if (chans[ch] < 0 || chans[ch] >= im->channels) {
        i_push_errorf(0, "No channel %d in this image", chans[ch]);
        return 0;
      }
    }
    for (i = 0; i < w; ++i) {
      i_color col;
      getter(surface, l+i, l+i+1, y, &col);
      for (ch = 0; ch < chan_count; ++ch) {
        *samps++ = col.channel[chans[ch]];
        ++count;
      }
    }
  }
  else {
    for (i = 0; i < w; ++i) {
      i_color col;
      getter(surface, l+i, l+i+1, y, &col);
      for (ch = 0; ch < chan_count; ++ch) {
        *samps++ = col.channel[ch];
        ++count;
      }
    }
  }
  DO_AUTO_UNLOCK(im);

  return count;
}

static int
i_ppixf_sdl_d(i_img *im, int x, int y, const i_fcolor *val) {
  return i_plinf_sdl_d(im, x, x+1, y, val);
}

static int 
i_gpixf_sdl_d(i_img *im, int x, int y, i_fcolor *val) {
  return i_glinf_sdl_d(im, x, x+1, y, val) ? 0 : -1;
}

static int
i_glinf_sdl_d(i_img *im, int l, int r, int y, i_fcolor *vals) {
  int count = 0;
  SDL_Surface *surface = IMSURFACE(im);
  sdl_get_func getter;
  int ch;

  if (l < 0 || l >= im->xsize)
    return 0;
  if (y < 0 || y >= im->ysize)
    return 0;

  if (r >= im->xsize)
    r = im->xsize;

  if (r <= l)
    return 0;

  count = r - l;

  DO_AUTO_LOCK(im);

  getter = get_getter(surface);
  while (l < r) {
    i_color col;
    getter(surface, l, l+1, y, &col);
    for (ch = 0; ch < im->channels; ++ch)
      vals->channel[ch] = Sample8ToF(col.channel[ch]);
    ++vals;
    ++l;
  }

  DO_AUTO_UNLOCK(im);

  return count;
}

static int
i_plinf_sdl_d(i_img *im, int l, int r, int y, const i_fcolor *vals) {
  int count = 0;
  SDL_Surface *surface = IMSURFACE(im);
  sdl_set_func setter;
  int ch;
  int x;

  if (l < 0 || l >= im->xsize)
    return 0;
  if (y < 0 || y >= im->ysize)
    return 0;

  if (r >= im->xsize)
    r = im->xsize;

  if (r <= l)
    return 0;

  count = r - l;

  DO_AUTO_LOCK(im);

  setter = get_setter(surface);
  x = l;
  while (x < r) {
    i_color col;
    for (ch = 0; ch < im->channels; ++ch)
      col.channel[ch] = SampleFTo8(vals->channel[ch]);
    setter(surface, x, x+1, y, &col);
    ++vals;
    ++x;
  }

  DO_AUTO_UNLOCK(im);

  if (ext(im)->auto_update)
    SDL_UpdateRect(IMSURFACE(im), l, r-l, y, 1);
  else
    freshen_update(ext(im), l, r, y);

  return count;
}

static int 
i_gsampf_sdl_d(i_img *im, int l, int r, int y, i_fsample_t *samps, const int *chans, int chan_count) {
  int count = 0;
  SDL_Surface *surface = IMSURFACE(im);
  sdl_get_func getter;
  int i, w, ch;

  if (l < 0 || l >= im->xsize)
    return 0;
  if (y < 0 || y >= im->ysize)
    return 0;

  if (r >= im->xsize)
    r = im->xsize;

  if (r <= l)
    return 0;

  DO_AUTO_LOCK(im);

  getter = get_getter(surface);
  w = r - l;
  if (chans) {
    /* make sure we have good channel numbers */
    for (ch = 0; ch < chan_count; ++ch) {
      if (chans[ch] < 0 || chans[ch] >= im->channels) {
        i_push_errorf(0, "No channel %d in this image", chans[ch]);
        return 0;
      }
    }
    for (i = 0; i < w; ++i) {
      i_color col;
      getter(surface, l+i, l+i+1, y, &col);
      for (ch = 0; ch < chan_count; ++ch) {
        *samps++ = Sample8ToF(col.channel[chans[ch]]);
        ++count;
      }
    }
  }
  else {
    for (i = 0; i < w; ++i) {
      i_color col;
      getter(surface, l+i, l+i+1, y, &col);
      for (ch = 0; ch < chan_count; ++ch) {
        *samps++ = Sample8ToF(col.channel[ch]);
        ++count;
      }
    }
  }
  DO_AUTO_UNLOCK(im);

  return count;
}

static void
i_destroy_sdl_d(i_img *im) {
  myfree(im->ext_data);
  im->ext_data = NULL;
}

static void
general_getter(SDL_Surface *surface, int l, int r, int y, i_color *col) {
  int bpp = surface->format->BytesPerPixel;
  /* Here p is the address to the pixel we want to retrieve */
  Uint8 *p;
  Uint32 raw; /* raw pixel value */

  if (l < 0 || y < 0 || l >= surface->w || y >= surface->h
      || r < 0 || r > surface->w)
    return;
  
  p = (Uint8 *)surface->pixels + y * surface->pitch + l * bpp;
  while (l < r) {
    switch(bpp) {
    case 1:
      raw = *p;
      ++p;
      break;
      
    case 2:
      raw = *(Uint16 *)p;
      p += 2;
      break;
      
    case 3:
      if(SDL_BYTEORDER == SDL_BIG_ENDIAN)
        raw = p[0] << 16 | p[1] << 8 | p[2];
      else
        raw = p[0] | p[1] << 8 | p[2] << 16;
      p += 3;
      break;
      
    case 4:
      raw = *(Uint32 *)p;
      p += 4;
      break;
    }
  
    /* extract the components */
    SDL_GetRGB(raw, surface->format, col->channel, col->channel+1, 
               col->channel+2);
    ++col;
    ++l;
  }
}

static void 
general_setter(SDL_Surface *surface, int l, int r, int y, const i_color *col) {
  int bpp = surface->format->BytesPerPixel;
  /* Here p is the address to the pixel we want to set */
  Uint8 *p = (Uint8 *)surface->pixels + y * surface->pitch + l * bpp;

  if (l < 0 || y < 0 || l >= surface->w || y >= surface->h
      || r < 0 || r > surface->w)
    return;
  
  while (l < r) {
    Uint32 pixel = SDL_MapRGB(surface->format, col->channel[0], 
                              col->channel[1], col->channel[2]);

    switch(bpp) {
    case 1:
      *p++ = pixel;
      break;
      
    case 2:
      *(Uint16 *)p = pixel;
      p += 2;
      break;
      
    case 3:
      if(SDL_BYTEORDER == SDL_BIG_ENDIAN) {
        p[0] = (pixel >> 16) & 0xff;
        p[1] = (pixel >> 8) & 0xff;
        p[2] = pixel & 0xff;
      } else {
        p[0] = pixel & 0xff;
        p[1] = (pixel >> 8) & 0xff;
        p[2] = (pixel >> 16) & 0xff;
      }
      p += 3;
      break;
      
    case 4:
      *(Uint32 *)p = pixel;
      p += 4;
      break;
    }
    ++l;
    ++col;
  }
}

/*
Update the update region...
 */
static void 
freshen_update(imsdl_ext *ext, int l, int r, int y) {
#ifdef SMART_UPDATES
  if (ext->left == -1) {
    ext->left = l;
    ext->right = r;
    ext->top = ext->bottom = y;
  }
  else {
    if (l < ext->left) ext->left = l;
    if (r > ext->right) ext->right = r;
    if (y < ext->top) ext->top = y;
    if (y > ext->bottom) ext->bottom = y;
  }
#endif
}
