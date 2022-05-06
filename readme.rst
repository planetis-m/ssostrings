====================================================
          Small String Optimized String
====================================================

The Small String Optimized (SSO) string data-type attempts to reduce the number
of heap allocations that happen at runtime. If a string is less than 23 bytes
on 64bit it can be stored directly in the object, avoiding a dynamic allocation.
There exist two modes for each String, a short string - and a long string mode
in which the dynamic memory is managed using Nim's destructors. The
implementation is based on clang's std::string class. This technique might
improve runtime performance and reduce fragmented memory where this is most
needed i.e. on embedded systems.
