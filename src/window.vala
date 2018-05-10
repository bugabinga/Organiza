using FileUtil;

namespace Organiza {
    [GtkTemplate (ui = "/org/organiza/Organiza/window.ui")]
    public class Window : Gtk.ApplicationWindow {
        [GtkChild]
        Gtk.TreeView fileView;
        [GtkChild]
        Gtk.ListStore currentFolderHierarchy;

        string currentDirectory = "/";
        FileMonitor ? currentDirectoryMonitor;

        // We needn't retrieve the theme over and over again.
        Gtk.IconTheme iconTheme = Gtk.IconTheme.get_default ();

        // TODO Marcel: I'd prefer using Icon.hash () over Icon.to_string (); Find out how to use uint properly in HashTable
        // Used for caching icons in order to decrease loading time when switching folders
        HashTable<string, Gdk.Pixbuf> iconCache = new HashTable<string, Gdk.Pixbuf>(str_hash, str_equal);

        public Window (Gtk.Application app) {
            Object (application: app);

            set_position (Gtk.WindowPosition.CENTER);
            set_default_size (700, 500);
            load_file_manager_icon ();
            update_file_view ();
            fileView.row_activated.connect (on_row_activated);
            fileView.key_press_event.connect (on_key_pressed);
        }

        private void load_file_manager_icon() {
            try {
                icon = iconTheme.load_icon ("system-file-manager", 48, 0);
            } catch ( Error e ) {
                warning (e.message);
                // In case we can't find an icon, we just won't set one.
            }
        }

        private void select_first() {
            Gtk.TreeIter iter;
            if ( currentFolderHierarchy.get_iter_first (out iter) ) {
                fileView.get_selection ().select_iter (iter);
                fileView.grab_focus ();
            }
        }

        private void update_file_view() {
            try {
                currentFolderHierarchy.clear ();

                var directory = File.new_for_path (currentDirectory);

                if ( currentDirectoryMonitor != null ) {
                    currentDirectoryMonitor.cancel ();
                }
                currentDirectoryMonitor = directory.monitor (FileMonitorFlags.NONE, null);
                currentDirectoryMonitor.changed.connect ((src, dest, event) => {
                    // TODO Marcel: Might it be better if i only update the entry containg the file?
                    update_file_view ();
                });

                Gtk.TreeIter iter;

                // If there is a parent-folder, we wan't to give the user the opportunity to navigate there per mouse, therefore we add an `..` item.
                var parentFolder = directory.get_parent ();
                if ( parentFolder != null ) {
                    currentFolderHierarchy.append (out iter);
                    var folderIcon = iconTheme.lookup_icon ("folder", 24, Gtk.IconLookupFlags.USE_BUILTIN).load_icon ();
                    currentFolderHierarchy.set (iter, 0, folderIcon, 1, "..", 2, "");
                }

                // FIXME The documentation suggests to use enumerate_children_async to not block the thread.
                var enumerator = directory.enumerate_children ("standard::*", FileQueryInfoFlags.NONE);

                FileInfo childFileInfo;
                while ( (childFileInfo = enumerator.next_file ()) != null ) {
                    currentFolderHierarchy.append (out iter);

                    string fileSize;
                    if ( childFileInfo.get_file_type () == FileType.DIRECTORY ) {
                        // Calculating a directories recursively takes too long, therefore we won't display such info.
                        fileSize = "";
                    } else {
                        fileSize = FileUtil.as_nerd_readable_file_size (childFileInfo.get_size ());
                    }

                    currentFolderHierarchy.set (iter, 0, get_pixbuf_icon (childFileInfo), 1, childFileInfo.get_name (), 2, fileSize);
                }
            } catch ( Error e ) {
                stderr.printf ("Error: %s\n", e.message);
            }
            select_first ();
        }

        private Gdk.Pixbuf ? get_pixbuf_icon (FileInfo info) {
            // TODO Consider not using a constant icon size.
            // TODO Implement a proper error-treatment.

            try {
                var icon = info.get_icon ();
                var iconHash = icon.to_string ();
                var pixbuf = iconCache.get (iconHash);
                if ( pixbuf == null ) {
                    // If the icon isn't cached yet, we will look it up, add it to the cache and return it.
                    pixbuf = iconTheme.lookup_by_gicon (icon, 24, Gtk.IconLookupFlags.USE_BUILTIN).load_icon ();
                    iconCache.insert (iconHash, pixbuf);
                }

                // by now pixbuf will be non-null and cached.
                return pixbuf;
            } catch ( Error error ) {
                stderr.printf ("Error retrieving icon for file: %s\n", info.get_name ());
                return null;
            }
        }

        /**
         * Handles leftclicks in the fileView.
         */
        private void on_row_activated(Gtk.TreeView treeview, Gtk.TreePath path, Gtk.TreeViewColumn column) {
            if ( get_selected_file_name () == ".." ) {
                navigate_up ();
            } else {
                navigate_down ();
            }
        }

        private bool on_key_pressed(Gtk.Widget widget, Gdk.EventKey event) {
            if ( event.keyval == Gdk.Key.Left ) {
                navigate_up ();
                return true;
            } else if ( event.keyval == Gdk.Key.Right ) {
                if ( get_selected_file_name () != ".." ) {
                    navigate_down ();
                    return true;
                }
            }

            return false;
        }

        private void navigate_up() {
            var parentFolder = File.new_for_path (currentDirectory).get_parent ();
            if ( parentFolder != null ) {
                currentDirectory = parentFolder.get_path ();
                update_file_view ();
            }
        }

        private void navigate_down() {
            var file = get_selected_file ();
            if ( FileUtil.is_directory (file) ) {
                currentDirectory = currentDirectory + "/" + file.get_basename ();
                update_file_view ();
            }
        }

        private string ? get_selected_file_name () {
            Gtk.TreeModel model;
            Gtk.TreeIter iter;
            string name;

            fileView.get_selection ().get_selected (out model, out iter);
            model.get (iter, 1, out name);
            return name;
        }

        private File ? get_selected_file () {
            return File.new_for_path (currentDirectory + "/" + get_selected_file_name ());
        }

    }

}
