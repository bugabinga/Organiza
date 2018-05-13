# These sources are shared with the main application and unit tests.
organiza_sources = files([
  'files/fileutil.vala',
  'gui/iconmanager.vala',
  'window.vala',
])

organiza_main = files('main.vala')

# this finds the math library in a portable way
cc = meson.get_compiler('c')
math_dep = cc.find_library('m', required : true)

valac = meson.get_compiler('vala')



# This mess is a workarpund for a bug in libgit2-glib version < 0.26.
# The vapi file is named 'ggit-1.0' instead of of 'libgit2-glib-1.0'.
# As soon as we drop support for versions older than 0.26, only the following will be necessary:
#libgit2 = dependency('libgit2-glib-1.0', version: '>= 0.26')
libgit2_lib = cc.find_library('libgit2-glib-1.0')
libgit2_vapi = valac.find_library('ggit-1.0', required: false)
if libgit2_vapi.found()
  message('Found older libgit2-glib version with incorrect vapi name. This got fixed in libgit2-glib version 0.26.')
else
  libgit2_vapi = valac.find_library('libgit2-glib-1.0')
endif
libgit2_dep = declare_dependency(dependencies: [libgit2_lib, libgit2_vapi])

organiza_deps = [
  dependency('gio-2.0', version: '>= 2.48'),
  dependency('gtk+-3.0', version: '>= 3.18'),
  dependency('glib-2.0', version: '>= 2.48'),
  libgit2_dep,
  math_dep,
]

gnome = import('gnome')

organiza_sources += gnome.compile_resources('organiza-resources',
  'organiza.gresource.xml',
  c_name: 'organiza'
)

executable('organiza', organiza_sources, organiza_main,
  dependencies: organiza_deps,
  install: true,
)
