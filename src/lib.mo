import List "mo:base/List";
import TrieSet "mo:base/TrieSet";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Timer "mo:base/Timer";
import Array "mo:base/Array";
import Nat "mo:base/Nat";

module {

  /// An RxMO Subject is a special type of Observable that allows values to be multicasted to many Observers. While plain Observables are unicast (each subscribed Observer owns an independent execution of the Observable), Subjects are multicast.
  ///
  /// Example:
  /// ```motoko
  /// let main = Subject<Nat>();
  /// var counter:Nat = 0;
  /// ignore main.subscribe({
  ///     next = func (v) {
  ///         counter += v;
  ///     };
  ///     complete = null_func
  /// });
  ///
  /// let unsubscribe = main.subscribe({
  ///     next = func (v) {
  ///         counter += v;
  ///     };
  ///     complete = null_func
  /// });
  ///
  /// main.next(1); // added twice
  /// main.next(2); // added twice
  /// main.next(3); // added twice
  /// unsubscribe();
  /// main.next(4); // added once
  /// main.complete();
  /// main.next(10); // not added because of complete
  /// assert(counter == 16);
  /// ```
  ///
  public func Subject<A>() : Observable<A>{
      return object {
        var observers = List.nil<(Nat, Observer<A>)>();
        var nextId: Nat = 0;

        public func next<system>( val: A ) : () {
          for (li in List.toIter(observers)) {
            li.1.next<system>( val );
          }
        };

        public func complete<system>() : () {
          for (li in List.toIter(observers)) {
            li.1.complete<system>();
          };
          observers := List.nil<(Nat, Observer<A>)>(); // remove all observers
        };

        public func subscribe<system>( z : Observer<A> ) : UnsubscribeFn {
          let id = nextId;
          nextId += 1;
          let unsubscribeFn : UnsubscribeFn = func() {
            observers := List.filter<(Nat, Observer<A>)>(observers, func (x) { x.0 != id });
          };

          observers := List.push((id, z), observers);
         
          unsubscribeFn;
        };
      }
  };

  /// Observables (unicast) are lazy Push collections of multiple values. They fill the missing spot in the following table:
  ///
  /// Example:
  /// ```motoko
  /// let ob = Observable<Nat>( func (subscriber) {
  ///     subscriber.next(3);
  ///     subscriber.next(5);
  ///     subscriber.next(12);
  ///     subscriber.complete();
  ///     subscriber.next(1231); // nothing happens after complete
  ///     subscriber.complete();
  /// });
  /// ```
  ///
  public func Observable<A>( sub : <system>(Observer<A>) -> () ) : Observable<A>{
 
    return object {
      public func next<system>( _: A ) : () {
        Debug.trap("Only available in Subject");
      };

      public func complete<system>() : () {
        Debug.trap("Only available in Subject");
      };

      public func subscribe<system>( z : Observer<A> ) : UnsubscribeFn {
        var ended : Bool = false;
        let unsubscribeFn :UnsubscribeFn = func() {
          ended := true;
        };

        let wrap:Observer<A> = {
          next = func<system>(x:A) { if (ended == false) z.next<system>(x) };
          complete = func<system>() { if (ended == false) { z.complete<system>(); unsubscribeFn(); } };
        };

        sub<system>(wrap);
      
        unsubscribeFn;
      };
    };

  };

  /// Observable 
  public type Observable<A> = {
    subscribe : <system>(Observer<A>) -> (UnsubscribeFn);
    next : <system>(A) -> ();
    complete : <system>() -> ();
  };

  /// MapAsync
  public func mapAsync<system, X,Y>(project: (X, next:<system>(Y) -> ()) -> async () ) : (Observable<X>) -> (Observable<Y>) {
    return func ( x : Observable<X> ) {
        Observable<Y>( func <system>(subscriber : Observer<Y>) {
          ignore x.subscribe<system>({
            next = func<system>(v:X) {
                   ignore Timer.setTimer<system>(#seconds 0, func() : async () {
                      ignore project(v, subscriber.next);
                   });
            };
            complete = subscriber.complete
          })
        });
      }
  };

   

  /// RxMO is mostly useful for its operators, even though the Observable is the foundation. Operators are the essential pieces that allow complex asynchronous code to be easily composed in a declarative manner.
  /// You can pipe Operators to Observables using the `pipe*` functions.
  public type Operator<X,Y> = (Observable<X>) -> (Observable<Y>);

  /// Buffers the source Observable values until closingNotifier emits.
  public func buffer<X>( closingNotifier: Observable<()> ) : (Observable<X>) -> (Observable<[X]>) {

    return func ( x : Observable<X> ) {
        Observable<[X]>( func <system>(subscriber : Observer<[X]>) {

          var buffer : List.List<X> = List.nil();
          
          ignore closingNotifier.subscribe<system>({
              next = func<system>(_:()) {
                subscriber.next<system>( Array.reverse(List.toArray(buffer)) );
                buffer := List.nil();
              };
              complete = null_func;
          });
          
          ignore x.subscribe<system>({
            next = func<system>(v:X) {
                buffer := List.push<X>(v, buffer);
            };
            complete = func<system>() {
              subscriber.next<system>( Array.reverse(List.toArray(buffer)) );
              buffer := List.nil();
              subscriber.complete<system>();
            }
          })
        });
      }
  };


  /// Buffers the source Observable values and emits them every X seconds with up to Y items.
  public func bufferTime<X>( bufferSec: Nat, bufferMaxSize: Nat ) : (Observable<X>) -> (Observable<[X]>) {

    return func ( x : Observable<X> ) {
        Observable<[X]>( func <system>(subscriber : Observer<[X]>) {

          var buffer : List.List<X> = List.nil();
          var isComplete = false;

          var timerId: ?Timer.TimerId = null;
          let doer = func() : async () {
                    let todo = List.take(buffer, bufferMaxSize);
                    buffer := List.drop(buffer, bufferMaxSize);

                    let count = List.size(todo);
                   
                    subscriber.next<system>( Array.reverse(List.toArray(todo)) );
                    
                    
                    if (count == 0) {
                      switch(timerId) { case (?id) Timer.cancelTimer(id); case (null) () };
                      timerId := null;
                      if (isComplete) subscriber.complete<system>(); // no items and complete, pass it ahead
                      }
                  };

          ignore x.subscribe<system>({
            next = func<system>(v : X) {
                buffer := List.push<X>(v, buffer);
              
                if (timerId == null) {
                  timerId := ?Timer.recurringTimer<system>(#seconds bufferSec, doer);
                };
               
            };
            complete = func<system>() {
                 isComplete := true;
            }
          })
        });
      }
  };

  /// Recurring timer
  ///
  /// Example:
  /// ```motoko
  /// let mytimer = timer(10);
  /// mytimer.subscribe({
  ///   next = func () {
  ///     Debug.print("Prints every 10 sec");
  ///   };
  ///   complete = func () {
  ///   }
  /// });
  /// ```
  public func timer<system>( sec: Nat ) : Observable<()> {
    let obs = Subject<()>();

    let timerId = Timer.recurringTimer<system>(#seconds sec, func() : async () {
          obs.next<system>(());
      });

    ignore obs.subscribe<system>({
       next = func <system>(()) {};
       complete = func<system>() {
            Timer.cancelTimer(timerId);
       }
      });
      
    return obs;
  };

  /// Delays the emission of items from the source Observable by a given timeout.
  ///
  /// Example:
  /// ```motoko
  /// let trigger = Subject<Nat>();
  /// ignore pipe2(trigger, delay<Nat>(5)).subscribe( {
  ///   next = func (v) {
  ///     Debug.print("5 sec delayed value: " #Nat.toText(v));
  ///   };
  ///   complete = func () {
  ///   }
  /// });
  ///
  /// trigger.next(1);
  /// trigger.next(2);
  /// ```
  public func delay<system, X>( sec: Nat ) : (Observable<X>) -> (Observable<X>) {
    return func ( x : Observable<X> ) {
        Observable<X>( func <system>(subscriber : Observer<X>) {
          var timerId : ?Timer.TimerId = null; 
          ignore x.subscribe<system>({
            next = func<system>(v:X) {
                timerId := ?Timer.setTimer<system>(#seconds sec, func() : async () {
                    subscriber.next<system>( v )
                });
            };
            complete = func <system>() {
              switch(timerId) {
                case (?id) Timer.cancelTimer(id);
                case (null) ();
              };
              subscriber.complete<system>();
              }
          })
        });
      }
  };

  /// Triggers once after specified time
  public func timerOnce<system>( sec: Nat ) : Observable<()> {

    let obs = Subject<()>();

    let _cancel = Timer.setTimer<system>(#seconds sec, func() : async () {
          obs.next<system>();
      });

    return obs;
  };

  /// Emits the values emitted by the source Observable until a notifier Observable emits a value.
  /// `takeUntil` subscribes and begins mirroring the source Observable. It also
  /// monitors a second Observable, `notifier` that you provide. If the `notifier`
  /// emits a value, the output Observable stops mirroring the source Observable
  /// and completes. If the `notifier` doesn't emit any value and completes
  /// then `takeUntil` will pass all values.
  public func takeUntil<X,Y>( obsUntil: Observable<Y> ) : (Observable<X>) -> (Observable<X>) {
    return func ( x : Observable<X> ) {
        var isComplete : Bool = false;
        Observable<X>( func <system>(subscriber : Observer<X>) {

          ignore obsUntil.subscribe<system>({
            next = func <system>(_ : Y) { 
              if (isComplete) return;
              isComplete := true;
              subscriber.complete<system>();
              };
            complete = null_func
          });

          ignore x.subscribe<system>({
            next = func<system>(v : X) {
               if (isComplete) return;
               subscriber.next<system>( v );
            };
            complete = func<system>() {
              if (isComplete) return;
              isComplete := true;
              subscriber.complete<system>();
            }
          })

        });

      }
  };


  /// Applies an accumulator function over the source Observable, and returns the accumulated result when the source completes, given an optional initial value.
  public func reduce<X,Y>( project: (Y, X) -> (Y), initial: Y ) : (Observable<X>) -> (Observable<Y>) {
    var acc = initial; 
    return func ( x : Observable<X> ) {
        Observable<Y>( func <system>(subscriber : Observer<Y>) {
          ignore x.subscribe<system>({
            next = func<system>(v : X) {
               acc := project(acc, v);
            };
            complete = func<system>() {
              subscriber.next<system>( acc );
              subscriber.complete<system>();
            }
          })
        });
      }
  };

  /// Applies a given project function to each value emitted by the source Observable,
  /// and emits the resulting values as an Observable.
  ///
  /// Example:
  /// ```motoko
  /// ignore pipe3(
  ///     ob,
  ///     map<Nat,Nat16>( func (val) {
  ///          Nat16.fromNat(val + 10)
  ///     }),
  ///     map<Nat16,Nat>( func (val) {
  ///          Nat16.toNat(val + 30)
  ///     })
  /// ).subscribe( {
  ///     next = func (v) {
  ///     };
  ///     complete = func () {
  ///     }
  /// });
  /// ```
  ///
  public func map<X,Y>( project: (X) -> (Y) ) : (Observable<X>) -> (Observable<Y>) {
    return func ( x : Observable<X> ) {
        Observable<Y>( func <system>(subscriber : Observer<Y>) {
          ignore x.subscribe<system>({
            next = func<system>(v : X) {
               subscriber.next<system>( project(v) )
            };
            complete = subscriber.complete
          })
        });
      }
  };

  /// Returns an Observable that emits all items emitted by the source Observable that are distinct by comparison from previous items.
  public func distinct<X>( keySelect: (X) -> Blob ) : (Observable<X>) -> (Observable<X>) {
    return func ( x : Observable<X> ) {

        Observable<X>( func <system>(subscriber : Observer<X>) {

          var distinctKeys: TrieSet.Set<Blob> = TrieSet.empty<Blob>();

          ignore x.subscribe<system>({
            next = func<system>(v : X) {
              let myKey = keySelect(v);
              let myHash = Blob.hash(myKey);
              if (TrieSet.mem<Blob>(distinctKeys, myKey, myHash, Blob.equal) == false) {
                distinctKeys := TrieSet.put<Blob>(distinctKeys, myKey, myHash, Blob.equal);
                subscriber.next<system>( v );
              };

            };
            complete = subscriber.complete
          })
        });
    }
  };


  /// Emits only the first value (or the first value that meets some condition) emitted by the source Observable.
  public func first<X>( ) : (Observable<X>) -> (Observable<X>) {
    return func ( x : Observable<X> ) {
        Observable<X>( func <system>(subscriber : Observer<X>) {
          var first_one = true;
          ignore x.subscribe<system>({
            next = func<system>(v:X) {
               if (first_one == false) return;
               subscriber.next<system>( v );
               first_one := false;
               subscriber.complete<system>();
            };
            complete = func<system>() {
               if (first_one == false) return;
               subscriber.complete<system>();
            }
          })
        });
    }
  };

  /// Joins every Observable emitted by the source (a higher-order Observable), in a serial fashion.
  /// It subscribes to each inner Observable only after the previous inner Observable has completed, 
  /// and merges all of their values into the returned observable.
  public func concatAll<X>( ) : (Observable<Observable<X>>) -> (Observable<X>) {
      mergeInternals<Observable<X>, X>(1, func (x) {x} )
  };

  /// Projects each source value to an Observable which is merged in the output Observable.
  public func mergeMap<X,Y>( project: (X) -> (Observable<Y>), concurrent: Nat ) : (Observable<X>) -> (Observable<Y>) {
      mergeInternals<X,Y>(concurrent, project)
  };

  /// A process embodying the general "merge" strategy.
  private func mergeInternals<X,Y>(concurrent : Nat, project: (X) -> (Observable<Y>) ) : (Observable<X>) -> (Observable<Y>) {
    return func ( x : Observable<X> ) {
        Observable<Y>( func <system>(subscriber : Observer<Y>) {
          
          var active : Nat = 0; 
          var buffer : List.List<X> = List.nil();
          var isComplete = false;

          let checkComplete = func <system>() {
              if (isComplete and List.size(buffer) == 0 and active == 0) {
                subscriber.complete<system>();
              }
          };

          let doInnerSub = func <system>(obs : X) {
            active += 1;

            ignore project(obs).subscribe<system>({
              next = func<system>(v: Y) {
                subscriber.next<system>(v);
              };
              complete = func<system>() {
                active -= 1;

                while (List.size(buffer) > 0 and active < concurrent) {
                  let ?bufferedValue = List.get(buffer, 0) else Debug.trap("Internal Error");
                  buffer := List.drop(buffer, 1);
                  doInnerSub<system>(bufferedValue);
                };

                checkComplete<system>();
              };
            });
          };
          
          ignore x.subscribe<system>({
              next = func<system>(value : X) {
                 if (active < concurrent) {
                      doInnerSub<system>(value);
                    } else {
                      buffer := List.push(value, buffer);
                    }
              };
              complete = func<system>() {
                  isComplete := true;
                  checkComplete<system>();
                 
              };
          });
       
        });
    }
  };

  /// Creates observable and emits values from array
  ///
  /// Example:
  /// ```motoko
  /// of<Nat>( [1,1,2,1,3,4,4,5,5,5] )
  /// ```
  public func of<system, X>( arr : [X] ) : Observable<X> {
    Observable<X>( func<system>(subscriber : Observer<X>) {
        for (el in arr.vals()) {
          subscriber.next<system>(el);
        };
        
        subscriber.complete<system>();
    });
  };


  /// An Observer is a consumer of values delivered by an Observable. Observers are simply a set of callbacks, one for each type of notification delivered by the Observable: next and complete.
  public type Observer<X> = {
    next : <system>(X) -> ();
    complete : <system>() -> ();
  };
    


  public type SubscriberFn<A> = (Observer<A>) -> ();


  public type UnsubscribeFn = () -> ();


  public func pipe2<A,B>(ob: Observable<A>, op1 : Operator<A,B>) : Observable<B> {
        op1(ob)
  };
   
  public func pipe3<A,B,C>(ob: Observable<A>, op1 : Operator<A,B>, op2 : Operator<B,C>) : Observable<C> {
        op2(op1(ob))
  };

  public func pipe4<A,B,C,D>(ob: Observable<A>, op1 : Operator<A,B>, op2 : Operator<B,C>, op3 : Operator<C,D>) : Observable<D> {
        op3(op2(op1(ob)))
  };

  public func pipe5<A,B,C,D,E>(ob: Observable<A>, op1 : Operator<A,B>, op2 : Operator<B,C>, op3 : Operator<C,D>, op4 : Operator<D,E>) : Observable<E> {
        op4(op3(op2(op1(ob))))
  };

  public func pipe6<A,B,C,D,E,F>(ob: Observable<A>, op1 : Operator<A,B>, op2 : Operator<B,C>, op3 : Operator<C,D>, op4 : Operator<D,E>, op5 : Operator<E,F>) : Observable<F> {
        op5(op4(op3(op2(op1(ob)))))
  };

  public func pipe7<A,B,C,D,E,F,G>(ob: Observable<A>, op1 : Operator<A,B>, op2 : Operator<B,C>, op3 : Operator<C,D>, op4 : Operator<D,E>, op5 : Operator<E,F>, op6 : Operator<F,G>) : Observable<G> {
      op6(op5(op4(op3(op2(op1(ob))))))
  };

  public func pipe8<A,B,C,D,E,F,G,H>(ob: Observable<A>, op1 : Operator<A,B>, op2 : Operator<B,C>, op3 : Operator<C,D>, op4 : Operator<D,E>, op5 : Operator<E,F>, op6 : Operator<F,G>, op7 : Operator<G,H>) : Observable<H> {
      op7(op6(op5(op4(op3(op2(op1(ob)))))))
  };

  public func pipe9<A,B,C,D,E,F,G,H,I>(ob: Observable<A>, op1 : Operator<A,B>, op2 : Operator<B,C>, op3 : Operator<C,D>, op4 : Operator<D,E>, op5 : Operator<E,F>, op6 : Operator<F,G>, op7 : Operator<G,H>, op8 : Operator<H,I>) : Observable<I> {
      op8(op7(op6(op5(op4(op3(op2(op1(ob))))))))
  };

  public func pipe10<A,B,C,D,E,F,G,H,I,J>(ob: Observable<A>, op1 : Operator<A,B>, op2 : Operator<B,C>, op3 : Operator<C,D>, op4 : Operator<D,E>, op5 : Operator<E,F>, op6 : Operator<F,G>, op7 : Operator<G,H>, op8 : Operator<H,I>, op9 : Operator<I,J>) : Observable<J> {
      op9(op8(op7(op6(op5(op4(op3(op2(op1(ob)))))))))
  };

  public func pipe11<A,B,C,D,E,F,G,H,I,J,K>(ob: Observable<A>, op1 : Operator<A,B>, op2 : Operator<B,C>, op3 : Operator<C,D>, op4 : Operator<D,E>, op5 : Operator<E,F>, op6 : Operator<F,G>, op7 : Operator<G,H>, op8 : Operator<H,I>, op9 : Operator<I,J>, op10 : Operator<J,K>) : Observable<K> {
      op10(op9(op8(op7(op6(op5(op4(op3(op2(op1(ob))))))))))
  };

  public func pipe12<A,B,C,D,E,F,G,H,I,J,K,L>(ob: Observable<A>, op1 : Operator<A,B>, op2 : Operator<B,C>, op3 : Operator<C,D>, op4 : Operator<D,E>, op5 : Operator<E,F>, op6 : Operator<F,G>, op7 : Operator<G,H>, op8 : Operator<H,I>, op9 : Operator<I,J>, op10 : Operator<J,K>, op11 : Operator<K,L>) : Observable<L> {
      op11(op10(op9(op8(op7(op6(op5(op4(op3(op2(op1(ob)))))))))))
  };

  public func pipe13<A,B,C,D,E,F,G,H,I,J,K,L,M>(ob: Observable<A>, op1 : Operator<A,B>, op2 : Operator<B,C>, op3 : Operator<C,D>, op4 : Operator<D,E>, op5 : Operator<E,F>, op6 : Operator<F,G>, op7 : Operator<G,H>, op8 : Operator<H,I>, op9 : Operator<I,J>, op10 : Operator<J,K>, op11 : Operator<K,L>, op12 : Operator<L,M>) : Observable<M> {
      op12(op11(op10(op9(op8(op7(op6(op5(op4(op3(op2(op1(ob))))))))))))
  };

  public func pipe14<A,B,C,D,E,F,G,H,I,J,K,L,M,N>(ob: Observable<A>, op1 : Operator<A,B>, op2 : Operator<B,C>, op3 : Operator<C,D>, op4 : Operator<D,E>, op5 : Operator<E,F>, op6 : Operator<F,G>, op7 : Operator<G,H>, op8 : Operator<H,I>, op9 : Operator<I,J>, op10 : Operator<J,K>, op11 : Operator<K,L>, op12 : Operator<L,M>, op13 : Operator<M,N>) : Observable<N> {
      op13(op12(op11(op10(op9(op8(op7(op6(op5(op4(op3(op2(op1(ob)))))))))))))
  };

  public func pipe15<A,B,C,D,E,F,G,H,I,J,K,L,M,N,O>(ob: Observable<A>, op1 : Operator<A,B>, op2 : Operator<B,C>, op3 : Operator<C,D>, op4 : Operator<D,E>, op5 : Operator<E,F>, op6 : Operator<F,G>, op7 : Operator<G,H>, op8 : Operator<H,I>, op9 : Operator<I,J>, op10 : Operator<J,K>, op11 : Operator<K,L>, op12 : Operator<L,M>, op13 : Operator<M,N>, op14 : Operator<N,O>) : Observable<O> {
      op14(op13(op12(op11(op10(op9(op8(op7(op6(op5(op4(op3(op2(op1(ob))))))))))))))
  };

  public func pipe16<A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P>(ob: Observable<A>, op1 : Operator<A,B>, op2 : Operator<B,C>, op3 : Operator<C,D>, op4 : Operator<D,E>, op5 : Operator<E,F>, op6 : Operator<F,G>, op7 : Operator<G,H>, op8 : Operator<H,I>, op9 : Operator<I,J>, op10 : Operator<J,K>, op11 : Operator<K,L>, op12 : Operator<L,M>, op13 : Operator<M,N>, op14 : Operator<N,O>, op15 : Operator<O,P>) : Observable<P> {
      op15(op14(op13(op12(op11(op10(op9(op8(op7(op6(op5(op4(op3(op2(op1(ob)))))))))))))))
  };


  /// A function that does nothing
  public let null_func = func<system>() {};
  
}