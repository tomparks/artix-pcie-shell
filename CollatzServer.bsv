package CollatzServer;

import FIFO::*;

(* synthesize *)
module mkTb(Empty);

  Ifc_type ifc <- mkCollatzServer;

  // This feels very clumsy as a way to test a server; I'd prefer a quickCheck
  // against a procedural impl.
  Reg#(Bool) submitted <- mkReg(False);
  rule run (!submitted);
    $display("submitting");

    ifc.collatz_submit(989345275647);
    submitted <= True;
    $display("submitted");
  endrule

  // this needs to be seperate to the launch rule; rules exec atomically;
  // the collatz_get preconditons (non-empty queue) cannot be satisfied until
  // the rule would have allredy executed if start and finish were combined.
  rule finish_test;
    $display("hello world, reply %0d", ifc.collatz_get());
    $finish(0);
  endrule

endmodule: mkTb

// We will make a specific type, so you can decouple the internal impl
// and the adaptors for calling from python
// interface REPLType;
//   method Action collatz_submit(Int#(64) n);
//   method ActionValue#(Int#(64)) collatz_get();
// endinterface: REPLType
//
//
// (* synthesize *)
// module BsREPL(REPLType);
//   // This module should expose the methods callable by the host
//   Ifc_type ifc <- mkCollatzServer;
// endmodule: BsREPL

interface Ifc_type;
  method Action collatz_submit(Int#(64) n);
  method ActionValue#(Int#(64)) collatz_get();
endinterface: Ifc_type
//
(* synthesize *)
module mkCollatzServer(Ifc_type);

  // FIFOs are stdlib modules, and the behavior is integrated in a very cool way.
  FIFO#(Int#(64)) req <- mkFIFO;
  FIFO#(Int#(64)) resp <- mkFIFO;

  // set up some storage locations for the collatz computation.
  // a reg has 2 methods, _read and _write but there is sugar allowing the bare name to mean read
  // and <= to mean write
  Reg#(Int#(64)) iteration_count <- mkReg (0);
  Reg#(Int#(64)) value <- mkReg (0);
  Reg#(Bool) running <- mkReg (False);

  // Rules are atomic actions that are protected by guards.
  // this rule has 2 conditions: a explicit check that we are not currently processing (!running)
  // and a implicit dependency on the req queue being not empty, generated by req.deq!
  rule start (!running);
    req.deq;
    running <= True;
    value <= req.first;
    iteration_count <= 0;
  endrule

  // the rules are sort-of global; can bsv build a efficient control logic tree
  // for the running -> value > 1 -> value % 2 chain?
  rule enditer (running && value == 1);
    running <= False;
    resp.enq(iteration_count);
  endrule

  // The collatz step rules
  rule even (running && (value % 2 == 0) && (value > 1));
    iteration_count <= iteration_count + 1;
    value <= value / 2;
  endrule

  rule odd (running && (value % 2 != 0) && (value > 1));
    iteration_count <= iteration_count + 1;
    value <= (3*value) + 1;
  endrule

  // A action method is a external interface that causes some state change in the module.
  method Action collatz_submit(Int#(64) n);
    req.enq(n);
    $display("collatz_submit %d", n);
  endmethod

  // A actionValue method causes state change and returns a value; this allows this method
  // to be guarded by resp.deq being non-empty; and bluespec will generate a valid network
  // so the calling code cannot violate the precondition!
  method ActionValue#(Int#(64)) collatz_get();
    resp.deq;
    let count = resp.first;
    $display("get response %h", count);
    return count;
  endmethod

endmodule: mkCollatzServer

// (* synthesize *)
// module mkCollatzServer(Ifc_type);
//   FIFO#(Int#(64)) fifo <- mkFIFO;
//
//     method Action collatz_submit(Int#(64) n);
//       fifo.enq(n);
//       $display("collatz_submit %d", n);
//     endmethod
//
//     method ActionValue#(Int#(64)) collatz_get();
//       fifo.deq;
//       let count = fifo.first;
//       $display("get response %h", count);
//       return count;
//     endmethod
//
// endmodule: mkCollatzServer

endpackage: CollatzServer
