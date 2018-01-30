'use strict';

var Caml_hash = require("./caml_hash.js");
var Bs_internalBuckets = require("./bs_internalBuckets.js");
var Bs_internalBucketsType = require("./bs_internalBucketsType.js");

function copyBucketReHash(h_buckets, ndata_tail, _old_bucket) {
  while(true) {
    var old_bucket = _old_bucket;
    if (old_bucket !== undefined) {
      var s = old_bucket.key;
      var nidx = Caml_hash.caml_hash_final_mix(Caml_hash.caml_hash_mix_string(0, s)) & (h_buckets.length - 1 | 0);
      var match = ndata_tail[nidx];
      if (match !== undefined) {
        match.next = old_bucket;
      } else {
        h_buckets[nidx] = old_bucket;
      }
      ndata_tail[nidx] = old_bucket;
      _old_bucket = old_bucket.next;
      continue ;
      
    } else {
      return /* () */0;
    }
  };
}

function replaceInBucket(key, info, _cell) {
  while(true) {
    var cell = _cell;
    if (cell.key === key) {
      cell.value = info;
      return /* false */0;
    } else {
      var match = cell.next;
      if (match !== undefined) {
        _cell = match;
        continue ;
        
      } else {
        return /* true */1;
      }
    }
  };
}

function set(h, key, value) {
  var h_buckets = h.buckets;
  var buckets_len = h_buckets.length;
  var i = Caml_hash.caml_hash_final_mix(Caml_hash.caml_hash_mix_string(0, key)) & (buckets_len - 1 | 0);
  var l = h_buckets[i];
  if (l !== undefined) {
    if (replaceInBucket(key, value, l)) {
      h_buckets[i] = {
        key: key,
        value: value,
        next: l
      };
      h.size = h.size + 1 | 0;
    }
    
  } else {
    h_buckets[i] = {
      key: key,
      value: value,
      next: Bs_internalBucketsType.emptyOpt
    };
    h.size = h.size + 1 | 0;
  }
  if (h.size > (buckets_len << 1)) {
    var h$1 = h;
    var odata = h$1.buckets;
    var osize = odata.length;
    var nsize = (osize << 1);
    if (nsize >= osize) {
      var h_buckets$1 = new Array(nsize);
      var ndata_tail = new Array(nsize);
      h$1.buckets = h_buckets$1;
      for(var i$1 = 0 ,i_finish = osize - 1 | 0; i$1 <= i_finish; ++i$1){
        copyBucketReHash(h_buckets$1, ndata_tail, odata[i$1]);
      }
      for(var i$2 = 0 ,i_finish$1 = nsize - 1 | 0; i$2 <= i_finish$1; ++i$2){
        var match = ndata_tail[i$2];
        if (match !== undefined) {
          match.next = Bs_internalBucketsType.emptyOpt;
        }
        
      }
      return /* () */0;
    } else {
      return 0;
    }
  } else {
    return 0;
  }
}

function remove(h, key) {
  var h_buckets = h.buckets;
  var i = Caml_hash.caml_hash_final_mix(Caml_hash.caml_hash_mix_string(0, key)) & (h_buckets.length - 1 | 0);
  var bucket = h_buckets[i];
  if (bucket !== undefined) {
    if (bucket.key === key) {
      h_buckets[i] = bucket.next;
      h.size = h.size - 1 | 0;
      return /* () */0;
    } else {
      var h$1 = h;
      var key$1 = key;
      var _prec = bucket;
      var _buckets = bucket.next;
      while(true) {
        var buckets = _buckets;
        var prec = _prec;
        if (buckets !== undefined) {
          var cell_next = buckets.next;
          if (buckets.key === key$1) {
            prec.next = cell_next;
            h$1.size = h$1.size - 1 | 0;
            return /* () */0;
          } else {
            _buckets = cell_next;
            _prec = buckets;
            continue ;
            
          }
        } else {
          return /* () */0;
        }
      };
    }
  } else {
    return /* () */0;
  }
}

function get(h, key) {
  var h_buckets = h.buckets;
  var nid = Caml_hash.caml_hash_final_mix(Caml_hash.caml_hash_mix_string(0, key)) & (h_buckets.length - 1 | 0);
  var match = h_buckets[nid];
  if (match !== undefined) {
    if (key === match.key) {
      return /* Some */[match.value];
    } else {
      var match$1 = match.next;
      if (match$1 !== undefined) {
        if (key === match$1.key) {
          return /* Some */[match$1.value];
        } else {
          var match$2 = match$1.next;
          if (match$2 !== undefined) {
            if (key === match$2.key) {
              return /* Some */[match$2.value];
            } else {
              var key$1 = key;
              var _buckets = match$2.next;
              while(true) {
                var buckets = _buckets;
                if (buckets !== undefined) {
                  if (key$1 === buckets.key) {
                    return /* Some */[buckets.value];
                  } else {
                    _buckets = buckets.next;
                    continue ;
                    
                  }
                } else {
                  return /* None */0;
                }
              };
            }
          } else {
            return /* None */0;
          }
        }
      } else {
        return /* None */0;
      }
    }
  } else {
    return /* None */0;
  }
}

function has(h, key) {
  var h_buckets = h.buckets;
  var nid = Caml_hash.caml_hash_final_mix(Caml_hash.caml_hash_mix_string(0, key)) & (h_buckets.length - 1 | 0);
  var bucket = h_buckets[nid];
  if (bucket !== undefined) {
    var key$1 = key;
    var _cell = bucket;
    while(true) {
      var cell = _cell;
      if (cell.key === key$1) {
        return /* true */1;
      } else {
        var match = cell.next;
        if (match !== undefined) {
          _cell = match;
          continue ;
          
        } else {
          return /* false */0;
        }
      }
    };
  } else {
    return /* false */0;
  }
}

function make(size) {
  return Bs_internalBucketsType.make(/* () */0, /* () */0, size);
}

function size(prim) {
  return prim.size;
}

function ofArray(arr) {
  var len = arr.length;
  var v = Bs_internalBucketsType.make(/* () */0, /* () */0, len);
  for(var i = 0 ,i_finish = len - 1 | 0; i <= i_finish; ++i){
    var match = arr[i];
    set(v, match[0], match[1]);
  }
  return v;
}

function mergeMany(h, arr) {
  var len = arr.length;
  for(var i = 0 ,i_finish = len - 1 | 0; i <= i_finish; ++i){
    var match = arr[i];
    set(h, match[0], match[1]);
  }
  return /* () */0;
}

var clear = Bs_internalBucketsType.clear;

var isEmpty = Bs_internalBucketsType.isEmpty;

var copy = Bs_internalBuckets.copy;

var forEach = Bs_internalBuckets.forEach;

var reduce = Bs_internalBuckets.reduce;

var keepMapInPlace = Bs_internalBuckets.keepMapInPlace;

var toArray = Bs_internalBuckets.toArray;

var keysToArray = Bs_internalBuckets.keysToArray;

var valuesToArray = Bs_internalBuckets.valuesToArray;

var getBucketHistogram = Bs_internalBuckets.getBucketHistogram;

var logStats = Bs_internalBuckets.logStats;

exports.make = make;
exports.clear = clear;
exports.isEmpty = isEmpty;
exports.set = set;
exports.copy = copy;
exports.get = get;
exports.has = has;
exports.remove = remove;
exports.forEach = forEach;
exports.reduce = reduce;
exports.keepMapInPlace = keepMapInPlace;
exports.size = size;
exports.toArray = toArray;
exports.keysToArray = keysToArray;
exports.valuesToArray = valuesToArray;
exports.ofArray = ofArray;
exports.mergeMany = mergeMany;
exports.getBucketHistogram = getBucketHistogram;
exports.logStats = logStats;
/* No side effect */