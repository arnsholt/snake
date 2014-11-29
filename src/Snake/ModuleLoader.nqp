class Snake::ModuleLoader;

my $loaded_setting;

method search_path($file) {
    my $path;
    for ['.', 'blib'] -> $prefix {
        if nqp::stat("$prefix/$file", 0) {
            $path := "$prefix/$file";
            last;
        }
    }
    nqp::die("Unable to locate $file") if !$path;
    $path
}

# Setting loading, how does it work?
# So this is slightly magical and mostly stolen from NQP, but as far as I grok
# it, this is the deal:
#
# 1) YOU_ARE_HERE creates the AST from Snake::Actions.CTXSAVE, which is
# inherited from HLL::Actions. This is a bit of code that looks up $*CTXSAVE,
# and if that object is able to .ctxsave(), calls that method on it.
#
# 2) The module loader sets $*CTXSAVE to itself, and loads the setting, which
# will call the code above as part of its mainline, triggering a call on
# .ctxsave(), where we save a reference to the context of the calling code,
# sc. the lexical environment we want code to run in.
method load_setting($name) {
    my $setting;

    if $name ne "NULL" {
        unless $loaded_setting {
            my $path := self.search_path("$name.setting.moarvm"); # XXX: Backend specific!
            my $*CTXSAVE := self;
            my $*MAIN_CTX := Snake::ModuleLoader;
            nqp::loadbytecode($path);

            if !nqp::defined($*MAIN_CTX) {
                nqp::die("Couldn't load setting $name; maybe it's missing a YOU_ARE_HERE?");
            }
            $loaded_setting := $*MAIN_CTX;
        }
        $setting := $loaded_setting;
    }

    $setting;
}

method ctxsave() {
    $*MAIN_CTX := nqp::ctxcaller(nqp::ctx());
    $*CTXSAVE := 0;
}

nqp::bindhllsym('snake', 'ModuleLoader', Snake::ModuleLoader);

# vim: ft=perl6
