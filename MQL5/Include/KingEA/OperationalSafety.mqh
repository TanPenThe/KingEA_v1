#ifndef KINGEA_OPERATIONAL_SAFETY_MQH
#define KINGEA_OPERATIONAL_SAFETY_MQH

// Stage 7 persistence, configuration, reconciliation, and heartbeat policy.
// This module contains no order submission, strategy history, indicator,
// performance, optimizer, OOS, holdout, DLL, or tick-flag capability.

#include <KingEA/SafetyKernel.mqh>

const int KINGEA_OPERATIONAL_SCHEMA=1;
#define KINGEA_MAX_INVENTORY 16

enum KingEAPersistenceStatus
  {
   KINGEA_PERSIST_OK=0,
   KINGEA_PERSIST_QUARANTINE=1,
   KINGEA_PERSIST_INVALID_CONTEXT=2,
   KINGEA_PERSIST_IO_FAILURE=3,
   KINGEA_PERSIST_CHECKSUM_FAILURE=4,
   KINGEA_PERSIST_IDENTITY_MISMATCH=5,
   KINGEA_PERSIST_SEQUENCE_FAILURE=6,
   KINGEA_PERSIST_GENESIS_REFUSED=7
  };

enum KingEAConfigurationStatus
  {
   KINGEA_CONFIG_OK=0,
   KINGEA_CONFIG_QUARANTINE=1,
   KINGEA_CONFIG_CHANGE_REJECTED_OPEN_EXPOSURE=2,
   KINGEA_CONFIG_NEW_VALIDATION_EPOCH=3
  };

enum KingEAReconciliationStatus
  {
   KINGEA_RECONCILED=0,
   KINGEA_RECONCILIATION_QUARANTINE=1
  };

struct KingEAPositionRecord
  {
   ulong  ticket;
   ulong  identifier;
   string symbol;
   int    direction;
   double volume;
   double open_price;
   double stop_loss;
   double take_profit;
   long   magic;
   string trade_group;
   string sleeve_id;
  };

struct KingEAOrderRecord
  {
   ulong  ticket;
   int    type;
   string symbol;
   double volume_initial;
   double volume_current;
   double entry_price;
   double stop_loss;
   double take_profit;
   long   magic;
   string trade_group;
   string sleeve_id;
  };

struct KingEAInventory
  {
   long                 account_login;
   string               server;
   int                  trade_mode;
   int                  margin_mode;
   int                  position_count;
   KingEAPositionRecord positions[KINGEA_MAX_INVENTORY];
   int                  order_count;
   KingEAOrderRecord    orders[KINGEA_MAX_INVENTORY];
  };

struct KingEAPersistentEnvelope
  {
   long              sequence;
   datetime          committed_utc;
   long              validation_epoch;
   double            risk_tier_percent;
   int               validation_trade_count;
   int               validation_clean_days;
   KingEASafetyState safety_state;
   KingEAInventory   expected_inventory;
  };

struct KingEAPersistenceContext
  {
   int    schema_version;
   string deployment_id;
   string candidate_hash;
   string configuration_hash;
   string safety_contract_hash;
   long   minimum_sequence;
   bool   genesis_authorized;
   bool   broker_flat;
   bool   exposure_reconciled;
   bool   affected_positions_open;
  };

struct KingEAPersistenceResult
  {
   KingEAPersistenceStatus status;
   bool                    quarantine;
   string                  reason;
   string                  selected_slot;
   KingEAPersistentEnvelope envelope;
  };

struct KingEAConfigurationBinding
  {
   string deployment_id;
   string candidate_hash;
   string configuration_hash;
   string safety_contract_hash;
   string build_id;
   string symbol;
   string server_class;
  };

struct KingEAConfigurationFacts
  {
   bool affected_positions_open;
   bool change_authorized;
   bool emergency_tightening;
  };

struct KingEAConfigurationResult
  {
   KingEAConfigurationStatus status;
   bool                      quarantine;
   bool                      reset_validation_clock;
   long                      next_validation_epoch;
   string                    reason;
  };

struct KingEAReconciliationResult
  {
   KingEAReconciliationStatus status;
   bool                       quarantine;
   string                     reason;
  };

struct KingEAHeartbeatContext
  {
   string deployment_id;
   string configuration_hash;
   string server_class;
   string executable_path;
   string data_root;
   long   process_id;
  };

struct KingEAHeartbeatResult
  {
   bool   ok;
   string reason;
   string path;
  };

string KingEABoolToken(const bool value)
  {
   return value ? "1" : "0";
  }

bool KingEATokenBool(string &tokens[],int &index,bool &value)
  {
   if(index>=ArraySize(tokens) || (tokens[index]!="0" && tokens[index]!="1"))
      return false;
   value=(tokens[index++]=="1");
   return true;
  }

bool KingEATokenInt(string &tokens[],int &index,int &value)
  {
   if(index>=ArraySize(tokens))
      return false;
   value=(int)StringToInteger(tokens[index++]);
   return true;
  }

bool KingEATokenLong(string &tokens[],int &index,long &value)
  {
   if(index>=ArraySize(tokens))
      return false;
   value=StringToInteger(tokens[index++]);
   return true;
  }

bool KingEATokenDouble(string &tokens[],int &index,double &value)
  {
   if(index>=ArraySize(tokens))
      return false;
   value=StringToDouble(tokens[index++]);
   return MathIsValidNumber(value);
  }

bool KingEATokenString(string &tokens[],int &index,string &value)
  {
   if(index>=ArraySize(tokens))
      return false;
   value=tokens[index++];
   return true;
  }

string KingEAHex(const uchar &bytes[])
  {
   string result="";
   for(int i=0;i<ArraySize(bytes);i++)
      result+=StringFormat("%02X",(int)bytes[i]);
   return result;
  }

string KingEASha256(const string payload)
  {
   uchar source[];
   uchar key[];
   uchar digest[];
   int count=StringToCharArray(payload,source,0,WHOLE_ARRAY,CP_UTF8);
   if(count<=0)
      return "";
   ArrayResize(source,count-1);
   if(CryptEncode(CRYPT_HASH_SHA256,source,key,digest)!=32)
      return "";
   return KingEAHex(digest);
  }

void KingEAAppendToken(string &payload,const string token)
  {
   if(StringLen(payload)>0)
      payload+="|";
   payload+=token;
  }

void KingEAAppendRecovery(string &payload,const KingEARecoveryState &state)
  {
   KingEAAppendToken(payload,KingEABoolToken(state.active));
   KingEAAppendToken(payload,IntegerToString(state.clean_days));
   KingEAAppendToken(payload,IntegerToString(state.throttle_events));
   KingEAAppendToken(payload,KingEABoolToken(state.manual_review_latched));
   KingEAAppendToken(payload,(string)(long)state.weekly_breaker_1);
   KingEAAppendToken(payload,(string)(long)state.weekly_breaker_2);
   KingEAAppendToken(payload,(string)(long)state.weekly_breaker_3);
   KingEAAppendToken(payload,IntegerToString(state.weekly_breaker_count));
   KingEAAppendToken(payload,(string)state.escalation_epoch);
   KingEAAppendToken(payload,KingEABoolToken(state.force_bottom_tier));
   KingEAAppendToken(payload,KingEABoolToken(state.day_health_failed));
  }

bool KingEAReadRecovery(string &tokens[],int &index,KingEARecoveryState &state)
  {
   long time_value=0;
   if(!KingEATokenBool(tokens,index,state.active) ||
      !KingEATokenInt(tokens,index,state.clean_days) ||
      !KingEATokenInt(tokens,index,state.throttle_events) ||
      !KingEATokenBool(tokens,index,state.manual_review_latched))
      return false;
   if(!KingEATokenLong(tokens,index,time_value)) return false;
   state.weekly_breaker_1=(datetime)time_value;
   if(!KingEATokenLong(tokens,index,time_value)) return false;
   state.weekly_breaker_2=(datetime)time_value;
   if(!KingEATokenLong(tokens,index,time_value)) return false;
   state.weekly_breaker_3=(datetime)time_value;
   return KingEATokenInt(tokens,index,state.weekly_breaker_count) &&
          KingEATokenLong(tokens,index,state.escalation_epoch) &&
          KingEATokenBool(tokens,index,state.force_bottom_tier) &&
          KingEATokenBool(tokens,index,state.day_health_failed);
  }

void KingEAAppendSafetyState(string &payload,const KingEASafetyState &state)
  {
   KingEAAppendToken(payload,KingEABoolToken(state.daily_paused));
   KingEAAppendToken(payload,KingEABoolToken(state.account_weekly_paused));
   KingEAAppendToken(payload,KingEABoolToken(state.account_monthly_latched));
   KingEAAppendToken(payload,KingEABoolToken(state.account_permanent_halt));
   KingEAAppendToken(payload,KingEABoolToken(state.sleeve_weekly_paused));
   KingEAAppendToken(payload,KingEABoolToken(state.sleeve_monthly_latched));
   KingEAAppendToken(payload,KingEABoolToken(state.sleeve_retired));
   KingEAAppendToken(payload,KingEABoolToken(state.account_revalidation_halt));
   KingEAAppendToken(payload,KingEABoolToken(state.account_weekly_breach_recorded));
   KingEAAppendToken(payload,KingEABoolToken(state.sleeve_weekly_breach_recorded));
   KingEAAppendToken(payload,IntegerToString(state.full_losses_today));
   KingEAAppendToken(payload,KingEABoolToken(state.final_trade_submitted));
   KingEAAppendToken(payload,(string)(long)state.broker_day_start);
   KingEAAppendToken(payload,(string)(long)state.broker_week_start);
   KingEAAppendToken(payload,(string)(long)state.broker_month_start);
   KingEAAppendRecovery(payload,state.account_recovery);
   KingEAAppendRecovery(payload,state.sleeve_recovery);
  }

bool KingEAReadSafetyState(string &tokens[],int &index,KingEASafetyState &state)
  {
   long time_value=0;
   if(!KingEATokenBool(tokens,index,state.daily_paused) ||
      !KingEATokenBool(tokens,index,state.account_weekly_paused) ||
      !KingEATokenBool(tokens,index,state.account_monthly_latched) ||
      !KingEATokenBool(tokens,index,state.account_permanent_halt) ||
      !KingEATokenBool(tokens,index,state.sleeve_weekly_paused) ||
      !KingEATokenBool(tokens,index,state.sleeve_monthly_latched) ||
      !KingEATokenBool(tokens,index,state.sleeve_retired) ||
      !KingEATokenBool(tokens,index,state.account_revalidation_halt) ||
      !KingEATokenBool(tokens,index,state.account_weekly_breach_recorded) ||
      !KingEATokenBool(tokens,index,state.sleeve_weekly_breach_recorded) ||
      !KingEATokenInt(tokens,index,state.full_losses_today) ||
      !KingEATokenBool(tokens,index,state.final_trade_submitted))
      return false;
   if(!KingEATokenLong(tokens,index,time_value)) return false;
   state.broker_day_start=(datetime)time_value;
   if(!KingEATokenLong(tokens,index,time_value)) return false;
   state.broker_week_start=(datetime)time_value;
   if(!KingEATokenLong(tokens,index,time_value)) return false;
   state.broker_month_start=(datetime)time_value;
   return KingEAReadRecovery(tokens,index,state.account_recovery) &&
          KingEAReadRecovery(tokens,index,state.sleeve_recovery);
  }

void KingEAAppendPosition(string &payload,const KingEAPositionRecord &record)
  {
   KingEAAppendToken(payload,(string)record.ticket);
   KingEAAppendToken(payload,(string)record.identifier);
   KingEAAppendToken(payload,record.symbol);
   KingEAAppendToken(payload,IntegerToString(record.direction));
   KingEAAppendToken(payload,DoubleToString(record.volume,8));
   KingEAAppendToken(payload,DoubleToString(record.open_price,8));
   KingEAAppendToken(payload,DoubleToString(record.stop_loss,8));
   KingEAAppendToken(payload,DoubleToString(record.take_profit,8));
   KingEAAppendToken(payload,(string)record.magic);
   KingEAAppendToken(payload,record.trade_group);
   KingEAAppendToken(payload,record.sleeve_id);
  }

bool KingEAReadPosition(string &tokens[],int &index,KingEAPositionRecord &record)
  {
   long value=0;
   if(!KingEATokenLong(tokens,index,value)) return false;
   record.ticket=(ulong)value;
   if(!KingEATokenLong(tokens,index,value)) return false;
   record.identifier=(ulong)value;
   return KingEATokenString(tokens,index,record.symbol) &&
          KingEATokenInt(tokens,index,record.direction) &&
          KingEATokenDouble(tokens,index,record.volume) &&
          KingEATokenDouble(tokens,index,record.open_price) &&
          KingEATokenDouble(tokens,index,record.stop_loss) &&
          KingEATokenDouble(tokens,index,record.take_profit) &&
          KingEATokenLong(tokens,index,record.magic) &&
          KingEATokenString(tokens,index,record.trade_group) &&
          KingEATokenString(tokens,index,record.sleeve_id);
  }

void KingEAAppendOrder(string &payload,const KingEAOrderRecord &record)
  {
   KingEAAppendToken(payload,(string)record.ticket);
   KingEAAppendToken(payload,IntegerToString(record.type));
   KingEAAppendToken(payload,record.symbol);
   KingEAAppendToken(payload,DoubleToString(record.volume_initial,8));
   KingEAAppendToken(payload,DoubleToString(record.volume_current,8));
   KingEAAppendToken(payload,DoubleToString(record.entry_price,8));
   KingEAAppendToken(payload,DoubleToString(record.stop_loss,8));
   KingEAAppendToken(payload,DoubleToString(record.take_profit,8));
   KingEAAppendToken(payload,(string)record.magic);
   KingEAAppendToken(payload,record.trade_group);
   KingEAAppendToken(payload,record.sleeve_id);
  }

bool KingEAReadOrder(string &tokens[],int &index,KingEAOrderRecord &record)
  {
   long value=0;
   if(!KingEATokenLong(tokens,index,value)) return false;
   record.ticket=(ulong)value;
   return KingEATokenInt(tokens,index,record.type) &&
          KingEATokenString(tokens,index,record.symbol) &&
          KingEATokenDouble(tokens,index,record.volume_initial) &&
          KingEATokenDouble(tokens,index,record.volume_current) &&
          KingEATokenDouble(tokens,index,record.entry_price) &&
          KingEATokenDouble(tokens,index,record.stop_loss) &&
          KingEATokenDouble(tokens,index,record.take_profit) &&
          KingEATokenLong(tokens,index,record.magic) &&
          KingEATokenString(tokens,index,record.trade_group) &&
          KingEATokenString(tokens,index,record.sleeve_id);
  }

string KingEASerializeEnvelope(const KingEAPersistenceContext &context,
                               const KingEAPersistentEnvelope &envelope)
  {
   string payload="";
   KingEAAppendToken(payload,IntegerToString(context.schema_version));
   KingEAAppendToken(payload,context.deployment_id);
   KingEAAppendToken(payload,context.candidate_hash);
   KingEAAppendToken(payload,context.configuration_hash);
   KingEAAppendToken(payload,context.safety_contract_hash);
   KingEAAppendToken(payload,(string)envelope.sequence);
   KingEAAppendToken(payload,(string)(long)envelope.committed_utc);
   KingEAAppendToken(payload,(string)envelope.validation_epoch);
   KingEAAppendToken(payload,DoubleToString(envelope.risk_tier_percent,8));
   KingEAAppendToken(payload,IntegerToString(envelope.validation_trade_count));
   KingEAAppendToken(payload,IntegerToString(envelope.validation_clean_days));
   KingEAAppendSafetyState(payload,envelope.safety_state);
   KingEAAppendToken(payload,(string)envelope.expected_inventory.account_login);
   KingEAAppendToken(payload,envelope.expected_inventory.server);
   KingEAAppendToken(payload,IntegerToString(envelope.expected_inventory.trade_mode));
   KingEAAppendToken(payload,IntegerToString(envelope.expected_inventory.margin_mode));
   KingEAAppendToken(payload,IntegerToString(envelope.expected_inventory.position_count));
   for(int i=0;i<envelope.expected_inventory.position_count;i++)
      KingEAAppendPosition(payload,envelope.expected_inventory.positions[i]);
   KingEAAppendToken(payload,IntegerToString(envelope.expected_inventory.order_count));
   for(int i=0;i<envelope.expected_inventory.order_count;i++)
      KingEAAppendOrder(payload,envelope.expected_inventory.orders[i]);
   return payload;
  }

bool KingEAParseEnvelope(const string payload,
                         const KingEAPersistenceContext &context,
                         KingEAPersistentEnvelope &envelope,
                         string &reason)
  {
   string tokens[];
   int count=StringSplit(payload,'|',tokens);
   int index=0;
   int schema=0;
   string deployment,candidate,configuration,contract;
   long committed=0;
   if(count<=0 ||
      !KingEATokenInt(tokens,index,schema) ||
      !KingEATokenString(tokens,index,deployment) ||
      !KingEATokenString(tokens,index,candidate) ||
      !KingEATokenString(tokens,index,configuration) ||
      !KingEATokenString(tokens,index,contract))
     {
      reason="MALFORMED_HEADER";
      return false;
     }
   if(schema!=context.schema_version ||
      deployment!=context.deployment_id ||
      candidate!=context.candidate_hash ||
      configuration!=context.configuration_hash ||
      contract!=context.safety_contract_hash)
     {
      reason="IDENTITY_MISMATCH";
      return false;
     }
   if(!KingEATokenLong(tokens,index,envelope.sequence) ||
      !KingEATokenLong(tokens,index,committed) ||
      !KingEATokenLong(tokens,index,envelope.validation_epoch) ||
      !KingEATokenDouble(tokens,index,envelope.risk_tier_percent) ||
      !KingEATokenInt(tokens,index,envelope.validation_trade_count) ||
      !KingEATokenInt(tokens,index,envelope.validation_clean_days) ||
      !KingEAReadSafetyState(tokens,index,envelope.safety_state))
     {
      reason="MALFORMED_STATE";
      return false;
     }
   envelope.committed_utc=(datetime)committed;
   if(!KingEATokenLong(tokens,index,envelope.expected_inventory.account_login) ||
      !KingEATokenString(tokens,index,envelope.expected_inventory.server) ||
      !KingEATokenInt(tokens,index,envelope.expected_inventory.trade_mode) ||
      !KingEATokenInt(tokens,index,envelope.expected_inventory.margin_mode) ||
      !KingEATokenInt(tokens,index,envelope.expected_inventory.position_count))
     {
      reason="MALFORMED_INVENTORY";
      return false;
     }
   if(envelope.expected_inventory.position_count<0 ||
      envelope.expected_inventory.position_count>KINGEA_MAX_INVENTORY)
     {
      reason="POSITION_COUNT_INVALID";
      return false;
     }
   for(int i=0;i<envelope.expected_inventory.position_count;i++)
      if(!KingEAReadPosition(tokens,index,envelope.expected_inventory.positions[i]))
        {
         reason="POSITION_MALFORMED";
         return false;
        }
   if(!KingEATokenInt(tokens,index,envelope.expected_inventory.order_count) ||
      envelope.expected_inventory.order_count<0 ||
      envelope.expected_inventory.order_count>KINGEA_MAX_INVENTORY)
     {
      reason="ORDER_COUNT_INVALID";
      return false;
     }
   for(int i=0;i<envelope.expected_inventory.order_count;i++)
      if(!KingEAReadOrder(tokens,index,envelope.expected_inventory.orders[i]))
        {
         reason="ORDER_MALFORMED";
         return false;
        }
   if(index!=count)
     {
      reason="TRAILING_FIELDS";
      return false;
     }
   reason="OK";
   return true;
  }

string KingEAStateDirectory(const KingEAPersistenceContext &context)
  {
   return "KingEA\\state\\"+context.deployment_id;
  }

bool KingEAWriteSnapshot(const string path,const string payload)
  {
   string checksum=KingEASha256(payload);
   if(checksum=="")
      return false;
   int handle=FileOpen(path,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON,0,CP_UTF8);
   if(handle==INVALID_HANDLE)
      return false;
   FileWriteString(handle,payload+"\r\n"+checksum+"\r\n");
   FileFlush(handle);
   FileClose(handle);
   int verify=FileOpen(path,FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON,0,CP_UTF8);
   if(verify==INVALID_HANDLE)
      return false;
   string read_payload=FileReadString(verify);
   string read_checksum=FileReadString(verify);
   FileClose(verify);
   return read_payload==payload && read_checksum==checksum &&
          KingEASha256(read_payload)==read_checksum;
  }

bool KingEACommitSlot(const string directory,const string slot,const string payload)
  {
   string temp=directory+"\\snapshot_"+slot+".tmp";
   string target=directory+"\\snapshot_"+slot+".dat";
   if(!KingEAWriteSnapshot(temp,payload))
      return false;
   if(!FileMove(temp,FILE_COMMON,target,FILE_COMMON|FILE_REWRITE))
      return false;
   return true;
  }

bool KingEAReadSnapshot(const string path,
                        const KingEAPersistenceContext &context,
                        KingEAPersistentEnvelope &envelope,
                        string &payload,
                        string &reason)
  {
   int handle=FileOpen(path,FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON,0,CP_UTF8);
   if(handle==INVALID_HANDLE)
     {
      reason="MISSING";
      return false;
     }
   payload=FileReadString(handle);
   string checksum=FileReadString(handle);
   bool trailing=!FileIsEnding(handle);
   FileClose(handle);
   if(trailing || checksum=="" || KingEASha256(payload)!=checksum)
     {
      reason="CHECKSUM_FAILURE";
      return false;
     }
   return KingEAParseEnvelope(payload,context,envelope,reason);
  }

bool KingEAContextValid(const KingEAPersistenceContext &context)
  {
   return context.schema_version==KINGEA_OPERATIONAL_SCHEMA &&
          StringLen(context.deployment_id)>0 &&
          StringFind(context.deployment_id,"|")<0 &&
          StringLen(context.candidate_hash)>0 &&
          StringLen(context.configuration_hash)>0 &&
          StringLen(context.safety_contract_hash)>0;
  }

void KingEASetPersistenceFailure(KingEAPersistenceResult &result,
                                 const KingEAPersistenceStatus status,
                                 const string reason)
  {
   result.status=status;
   result.quarantine=true;
   result.reason=reason;
  }

void KingEACommitPersistentState(const KingEAPersistenceContext &context,
                                 const KingEAPersistentEnvelope &requested,
                                 KingEAPersistenceResult &result)
  {
   ZeroMemory(result);
   if(!KingEAContextValid(context))
     {
      KingEASetPersistenceFailure(result,KINGEA_PERSIST_INVALID_CONTEXT,"INVALID_CONTEXT");
      return;
     }
   bool genesis=(requested.sequence==0);
   if(genesis && (!context.genesis_authorized || !context.broker_flat ||
                  !context.exposure_reconciled || context.affected_positions_open))
     {
      KingEASetPersistenceFailure(result,KINGEA_PERSIST_GENESIS_REFUSED,"GENESIS_REQUIRES_FLAT_RECONCILED_AUTHORIZATION");
      return;
     }
   string directory=KingEAStateDirectory(context);
   if(!FolderCreate(directory,FILE_COMMON))
     {
      int error=GetLastError();
      if(error!=5010)
        {
         KingEASetPersistenceFailure(result,KINGEA_PERSIST_IO_FAILURE,
                                     "FOLDER_CREATE_FAILED_"+IntegerToString(error));
         return;
        }
     }
   KingEAPersistentEnvelope committed=requested;
   committed.sequence=requested.sequence+1;
   string payload=KingEASerializeEnvelope(context,committed);
   if(genesis)
     {
      if(!KingEACommitSlot(directory,"A",payload) ||
         !KingEACommitSlot(directory,"B",payload))
        {
         KingEASetPersistenceFailure(result,KINGEA_PERSIST_IO_FAILURE,"GENESIS_WRITE_FAILED");
         return;
        }
      result.selected_slot="A+B";
     }
   else
     {
      string slot=(committed.sequence%2==0 ? "A" : "B");
      if(!KingEACommitSlot(directory,slot,payload))
        {
         KingEASetPersistenceFailure(result,KINGEA_PERSIST_IO_FAILURE,"COMMIT_FAILED");
         return;
        }
      result.selected_slot=slot;
     }
   result.status=KINGEA_PERSIST_OK;
   result.quarantine=false;
   result.reason="OK";
   result.envelope=committed;
  }

void KingEALoadPersistentState(const KingEAPersistenceContext &context,
                               KingEAPersistenceResult &result)
  {
   ZeroMemory(result);
   if(!KingEAContextValid(context))
     {
      KingEASetPersistenceFailure(result,KINGEA_PERSIST_INVALID_CONTEXT,"INVALID_CONTEXT");
      return;
     }
   string directory=KingEAStateDirectory(context);
   KingEAPersistentEnvelope a={},b={};
   string payload_a="",payload_b="",reason_a="",reason_b="";
   bool valid_a=KingEAReadSnapshot(directory+"\\snapshot_A.dat",context,a,payload_a,reason_a);
   bool valid_b=KingEAReadSnapshot(directory+"\\snapshot_B.dat",context,b,payload_b,reason_b);
   if(!valid_a || !valid_b)
     {
      KingEASetPersistenceFailure(result,KINGEA_PERSIST_QUARANTINE,
                                  "REDUNDANT_PAIR_INVALID_A_"+reason_a+"_B_"+reason_b);
      if(valid_a) result.envelope=a;
      if(valid_b) result.envelope=b;
      return;
     }
   if(a.sequence==b.sequence && payload_a!=payload_b)
     {
      KingEASetPersistenceFailure(result,KINGEA_PERSIST_SEQUENCE_FAILURE,"CONFLICTING_EQUAL_SEQUENCE");
      return;
     }
   KingEAPersistentEnvelope selected=(a.sequence>=b.sequence ? a : b);
   string slot=(a.sequence>=b.sequence ? "A" : "B");
   if(selected.sequence<context.minimum_sequence)
     {
      KingEASetPersistenceFailure(result,KINGEA_PERSIST_SEQUENCE_FAILURE,"ROLLBACK_DETECTED");
      result.envelope=selected;
      return;
     }
   result.status=KINGEA_PERSIST_OK;
   result.quarantine=false;
   result.reason="OK";
   result.selected_slot=slot;
   result.envelope=selected;
  }

bool KingEAConfigurationEqual(const KingEAConfigurationBinding &a,
                              const KingEAConfigurationBinding &b)
  {
   return a.deployment_id==b.deployment_id &&
          a.candidate_hash==b.candidate_hash &&
          a.configuration_hash==b.configuration_hash &&
          a.safety_contract_hash==b.safety_contract_hash &&
          a.build_id==b.build_id &&
          a.symbol==b.symbol &&
          a.server_class==b.server_class;
  }

void KingEAVerifyConfiguration(const KingEAConfigurationBinding &approved,
                               const KingEAConfigurationBinding &runtime,
                               const KingEAConfigurationFacts &facts,
                               const long current_validation_epoch,
                               KingEAConfigurationResult &result)
  {
   ZeroMemory(result);
   result.next_validation_epoch=current_validation_epoch;
   if(KingEAConfigurationEqual(approved,runtime))
     {
      result.status=KINGEA_CONFIG_OK;
      result.reason="OK";
      return;
     }
   if(facts.affected_positions_open)
     {
      result.status=KINGEA_CONFIG_CHANGE_REJECTED_OPEN_EXPOSURE;
      result.quarantine=true;
      result.reason="CONFIGURATION_CHANGE_WITH_OPEN_EXPOSURE";
      return;
     }
   if(!facts.change_authorized && !facts.emergency_tightening)
     {
      result.status=KINGEA_CONFIG_QUARANTINE;
      result.quarantine=true;
      result.reason="UNAUTHORIZED_CONFIGURATION";
      return;
     }
   result.status=KINGEA_CONFIG_NEW_VALIDATION_EPOCH;
   result.reset_validation_clock=true;
   result.next_validation_epoch=current_validation_epoch+1;
   result.reason=facts.emergency_tightening ? "EMERGENCY_TIGHTENING_VERSION" : "APPROVED_CONFIGURATION_VERSION";
  }

bool KingEADoubleEqual(const double a,const double b)
  {
   return MathAbs(a-b)<=1e-9;
  }

bool KingEAPositionEqual(const KingEAPositionRecord &a,const KingEAPositionRecord &b)
  {
   return a.ticket==b.ticket && a.identifier==b.identifier &&
          a.symbol==b.symbol && a.direction==b.direction &&
          KingEADoubleEqual(a.volume,b.volume) &&
          KingEADoubleEqual(a.open_price,b.open_price) &&
          KingEADoubleEqual(a.stop_loss,b.stop_loss) &&
          KingEADoubleEqual(a.take_profit,b.take_profit) &&
          a.magic==b.magic && a.trade_group==b.trade_group &&
          a.sleeve_id==b.sleeve_id;
  }

bool KingEAOrderEqual(const KingEAOrderRecord &a,const KingEAOrderRecord &b)
  {
   return a.ticket==b.ticket && a.type==b.type && a.symbol==b.symbol &&
          KingEADoubleEqual(a.volume_initial,b.volume_initial) &&
          KingEADoubleEqual(a.volume_current,b.volume_current) &&
          KingEADoubleEqual(a.entry_price,b.entry_price) &&
          KingEADoubleEqual(a.stop_loss,b.stop_loss) &&
          KingEADoubleEqual(a.take_profit,b.take_profit) &&
          a.magic==b.magic && a.trade_group==b.trade_group &&
          a.sleeve_id==b.sleeve_id;
  }

void KingEAReconcileBrokerInventory(const KingEAInventory &expected,
                                    const KingEAInventory &actual,
                                    KingEAReconciliationResult &result)
  {
   ZeroMemory(result);
   result.status=KINGEA_RECONCILIATION_QUARANTINE;
   result.quarantine=true;
   if(expected.account_login!=actual.account_login ||
      expected.server!=actual.server ||
      expected.trade_mode!=actual.trade_mode ||
      expected.margin_mode!=actual.margin_mode)
     {
      result.reason="ACCOUNT_IDENTITY_MISMATCH";
      return;
     }
   if(expected.position_count!=actual.position_count ||
      expected.order_count!=actual.order_count ||
      expected.position_count<0 || expected.position_count>KINGEA_MAX_INVENTORY ||
      expected.order_count<0 || expected.order_count>KINGEA_MAX_INVENTORY)
     {
      result.reason="INVENTORY_COUNT_MISMATCH";
      return;
     }
   for(int i=0;i<expected.position_count;i++)
     {
      int matches=0;
      for(int j=0;j<actual.position_count;j++)
         if(KingEAPositionEqual(expected.positions[i],actual.positions[j]))
            matches++;
      if(matches!=1)
        {
         result.reason="POSITION_MISSING_ALTERED_OR_DUPLICATED";
         return;
        }
      if(expected.positions[i].stop_loss<=0.0)
        {
         result.reason="POSITION_UNPROTECTED";
         return;
        }
     }
   for(int i=0;i<expected.order_count;i++)
     {
      int matches=0;
      for(int j=0;j<actual.order_count;j++)
         if(KingEAOrderEqual(expected.orders[i],actual.orders[j]))
            matches++;
      if(matches!=1)
        {
         result.reason="ORDER_MISSING_ALTERED_OR_DUPLICATED";
         return;
        }
     }
   result.status=KINGEA_RECONCILED;
   result.quarantine=false;
   result.reason="OK";
  }

bool KingEAWriteHeartbeat(const KingEAHeartbeatContext &context,
                          const long sequence,
                          const datetime utc_now,
                          KingEAHeartbeatResult &result)
  {
   ZeroMemory(result);
   if(sequence<=0 || utc_now<=0 || context.deployment_id=="" ||
      context.configuration_hash=="" || context.server_class=="" ||
      context.executable_path=="" || context.data_root=="" || context.process_id<=0)
     {
      result.reason="INVALID_HEARTBEAT_CONTEXT";
      return false;
     }
   string directory="KingEA\\heartbeat\\"+context.deployment_id;
   FolderCreate(directory,FILE_COMMON);
   string payload="schema=1\n"+
                  "sequence="+(string)sequence+"\n"+
                  "utc="+(string)(long)utc_now+"\n"+
                  "deployment_id="+context.deployment_id+"\n"+
                  "configuration_hash="+context.configuration_hash+"\n"+
                  "server_class="+context.server_class+"\n"+
                  "process_id="+(string)context.process_id+"\n"+
                  "executable_path="+context.executable_path+"\n"+
                  "data_root="+context.data_root+"\n";
   string checksum=KingEASha256(payload);
   string temp=directory+"\\heartbeat.tmp";
   string target=directory+"\\heartbeat.dat";
   int handle=FileOpen(temp,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON,0,CP_UTF8);
   if(handle==INVALID_HANDLE)
     {
      result.reason="HEARTBEAT_OPEN_FAILED";
      return false;
     }
   FileWriteString(handle,payload+"sha256="+checksum+"\n");
   FileFlush(handle);
   FileClose(handle);
   if(!FileMove(temp,FILE_COMMON,target,FILE_COMMON|FILE_REWRITE))
     {
      result.reason="HEARTBEAT_MOVE_FAILED";
      return false;
     }
   result.ok=true;
   result.reason="OK";
   result.path=target;
   return true;
  }

#endif
