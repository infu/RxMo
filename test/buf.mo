import {Observable; null_func; delay; buffer; timerOnce; Subject; of; pipe2; pipe3; pipe4; first; map; concatAll; mergeMap; distinct; reduce; takeUntil} "./observable";
import Principal "mo:base/Principal";
import Timer "mo:base/Timer";
import Array "mo:base/Array";

actor Echo {

  let bump = Subject<Nat>();
  let trigger = Subject<()>();

  var count :Nat = 0;

  ignore pipe3(
      bump,
      buffer<Nat>(trigger),
      delay<[Nat]>(3)
  ).subscribe( {
      next = func (buf) {
          count += Array.foldRight<Nat, Nat>(buf, 0, func(x, acc) = x + acc)
      };
      complete = null_func;
  });
      
  public query func stats() : async Nat {
    return count;
  };

  public shared({caller}) func vote() : async () {
    bump.next(1);
    bump.next(2);
    trigger.next();

  } 
};
