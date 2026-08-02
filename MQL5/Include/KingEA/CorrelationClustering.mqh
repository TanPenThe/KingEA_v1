#ifndef KINGEA_CORRELATION_CLUSTERING_MQH
#define KINGEA_CORRELATION_CLUSTERING_MQH

#define KINGEA_CORRELATION_MAX_SYMBOLS 8
#define KINGEA_CORRELATION_MAX_POINTS 128
#define KINGEA_CORRELATION_MAX_PAIRS 28

enum KingEACorrelationReason
  {
   KINGEA_CORRELATION_REASON_OK=0,
   KINGEA_CORRELATION_REASON_INVALID_REQUEST=1,
   KINGEA_CORRELATION_REASON_INVALID_SERIES=2,
   KINGEA_CORRELATION_REASON_STALE_SERIES=3,
   KINGEA_CORRELATION_REASON_INSUFFICIENT_OVERLAP=4,
   KINGEA_CORRELATION_REASON_ZERO_VARIANCE=5
  };

struct KingEADailyCloseSeries
  {
   string symbol_id;
   int point_count;
   datetime close_times[KINGEA_CORRELATION_MAX_POINTS];
   double closes[KINGEA_CORRELATION_MAX_POINTS];
   bool fresh;
  };

struct KingEAStaticCorrelationOverride
  {
   string first_symbol;
   string second_symbol;
  };

struct KingEACorrelationPairState
  {
   string pair_key;
   bool edge_active;
   int release_clean_days;
   datetime last_evaluation_day;
  };

struct KingEACorrelationState
  {
   int pair_count;
   KingEACorrelationPairState pairs[KINGEA_CORRELATION_MAX_PAIRS];
  };

struct KingEACorrelationRequest
  {
   int symbol_count;
   KingEADailyCloseSeries series[KINGEA_CORRELATION_MAX_SYMBOLS];
   datetime expected_latest_close_time;
   int override_count;
   KingEAStaticCorrelationOverride overrides[KINGEA_CORRELATION_MAX_PAIRS];
  };

struct KingEACorrelationPairDecision
  {
   string pair_key;
   string first_symbol;
   string second_symbol;
   double correlation_60;
   double correlation_20;
   bool correlation_valid;
   bool static_override;
   bool edge_active;
   int release_clean_days;
   KingEACorrelationReason reason;
  };

struct KingEACorrelationMemberDecision
  {
   string symbol_id;
   string cluster_key;
   bool cluster_known;
  };

struct KingEACorrelationDecision
  {
   bool healthy;
   bool cluster_known;
   KingEACorrelationReason reason;
   int pair_count;
   KingEACorrelationPairDecision pairs[KINGEA_CORRELATION_MAX_PAIRS];
   int member_count;
   KingEACorrelationMemberDecision members[KINGEA_CORRELATION_MAX_SYMBOLS];
   KingEACorrelationState next_state;
  };

bool KingEACorrelationFinite(const double value)
  {
   return MathIsValidNumber(value);
  }

bool KingEACorrelationAtLeast(const double value,const double threshold)
  {
   return value>threshold || MathAbs(value-threshold)<=1e-10;
  }

string KingEACorrelationPairKey(const string first,const string second)
  {
   if(StringCompare(first,second)<0)
      return first+"|"+second;
   return second+"|"+first;
  }

int KingEACorrelationFindPrior(const KingEACorrelationState &prior,
                               const string pair_key)
  {
   for(int i=0;i<prior.pair_count && i<KINGEA_CORRELATION_MAX_PAIRS;i++)
      if(prior.pairs[i].pair_key==pair_key)
         return i;
   return -1;
  }

bool KingEACorrelationHasOverride(const KingEACorrelationRequest &request,
                                  const string pair_key)
  {
   for(int i=0;i<request.override_count &&
                   i<KINGEA_CORRELATION_MAX_PAIRS;i++)
      if(KingEACorrelationPairKey(request.overrides[i].first_symbol,
                                  request.overrides[i].second_symbol)==pair_key)
         return true;
   return false;
  }

KingEACorrelationReason KingEACorrelationValidateSeries(
   const KingEADailyCloseSeries &series,
   const datetime expected_latest)
  {
   if(series.symbol_id=="" || series.point_count<2 ||
      series.point_count>KINGEA_CORRELATION_MAX_POINTS)
      return KINGEA_CORRELATION_REASON_INVALID_SERIES;
   for(int i=0;i<series.point_count;i++)
     {
      if(series.close_times[i]<=0 ||
         ((long)series.close_times[i]%86400)!=0 ||
         !KingEACorrelationFinite(series.closes[i]) ||
         series.closes[i]<=0.0)
         return KINGEA_CORRELATION_REASON_INVALID_SERIES;
      if(i>0 && series.close_times[i]<=series.close_times[i-1])
         return KINGEA_CORRELATION_REASON_INVALID_SERIES;
     }
   if(!series.fresh ||
      series.close_times[series.point_count-1]!=expected_latest)
      return KINGEA_CORRELATION_REASON_STALE_SERIES;
   return KINGEA_CORRELATION_REASON_OK;
  }

bool KingEACorrelationPearson(const double &x[],
                              const double &y[],
                              const int start,
                              const int count,
                              double &correlation)
  {
   if(count<2)
      return false;
   double mean_x=0.0,mean_y=0.0;
   for(int i=start;i<start+count;i++)
     {
      mean_x+=x[i];
      mean_y+=y[i];
     }
   mean_x/=count;
   mean_y/=count;
   double covariance=0.0,variance_x=0.0,variance_y=0.0;
   for(int i=start;i<start+count;i++)
     {
      double dx=x[i]-mean_x;
      double dy=y[i]-mean_y;
      covariance+=dx*dy;
      variance_x+=dx*dx;
      variance_y+=dy*dy;
     }
   if(variance_x<=1e-24 || variance_y<=1e-24)
      return false;
   correlation=covariance/MathSqrt(variance_x*variance_y);
   if(!KingEACorrelationFinite(correlation))
      return false;
   if(correlation>1.0 && correlation<1.0+1e-10)
      correlation=1.0;
   if(correlation<-1.0 && correlation>-1.0-1e-10)
      correlation=-1.0;
   return correlation>=-1.0 && correlation<=1.0;
  }

KingEACorrelationReason KingEACorrelationCalculatePair(
   const KingEADailyCloseSeries &first,
   const KingEADailyCloseSeries &second,
   double &correlation_60,
   double &correlation_20)
  {
   datetime aligned_times[KINGEA_CORRELATION_MAX_POINTS];
   double first_returns[KINGEA_CORRELATION_MAX_POINTS];
   double second_returns[KINGEA_CORRELATION_MAX_POINTS];
   int aligned=0;
   int i=1,j=1;
   while(i<first.point_count && j<second.point_count)
     {
      datetime first_time=first.close_times[i];
      datetime second_time=second.close_times[j];
      if(first_time==second_time)
        {
         if(aligned>=KINGEA_CORRELATION_MAX_POINTS)
            return KINGEA_CORRELATION_REASON_INVALID_SERIES;
         aligned_times[aligned]=first_time;
         first_returns[aligned]=MathLog(first.closes[i]/first.closes[i-1]);
         second_returns[aligned]=MathLog(second.closes[j]/second.closes[j-1]);
         if(!KingEACorrelationFinite(first_returns[aligned]) ||
            !KingEACorrelationFinite(second_returns[aligned]))
            return KINGEA_CORRELATION_REASON_INVALID_SERIES;
         aligned++;
         i++;
         j++;
        }
      else if(first_time<second_time)
         i++;
      else
         j++;
     }
   if(aligned<60)
      return KINGEA_CORRELATION_REASON_INSUFFICIENT_OVERLAP;
   if(!KingEACorrelationPearson(first_returns,second_returns,
                                aligned-60,60,correlation_60) ||
      !KingEACorrelationPearson(first_returns,second_returns,
                                aligned-20,20,correlation_20))
      return KINGEA_CORRELATION_REASON_ZERO_VARIANCE;
   return KINGEA_CORRELATION_REASON_OK;
  }

void KingEACorrelationSortSymbols(string &symbols[],const int count)
  {
   for(int i=0;i<count;i++)
      for(int j=i+1;j<count;j++)
         if(StringCompare(symbols[j],symbols[i])<0)
           {
            string temporary=symbols[i];
            symbols[i]=symbols[j];
            symbols[j]=temporary;
           }
  }

int KingEACorrelationFindSymbol(const string &symbols[],
                                const int count,
                                const string symbol)
  {
   for(int i=0;i<count;i++)
      if(symbols[i]==symbol)
         return i;
   return -1;
  }

int KingEACorrelationFindRoot(int &parents[],int index)
  {
   while(parents[index]!=index)
     {
      parents[index]=parents[parents[index]];
      index=parents[index];
     }
   return index;
  }

void KingEACorrelationUnion(int &parents[],const int first,const int second)
  {
   int root_first=KingEACorrelationFindRoot(parents,first);
   int root_second=KingEACorrelationFindRoot(parents,second);
   if(root_first==root_second)
      return;
   if(root_first<root_second)
      parents[root_second]=root_first;
   else
      parents[root_first]=root_second;
  }

// Sole Stage 10 correlation-clustering interface.
void KingEAEvaluateCorrelation(const KingEACorrelationRequest &request,
                               const KingEACorrelationState &prior,
                               KingEACorrelationDecision &decision)
  {
   ZeroMemory(decision);
   decision.reason=KINGEA_CORRELATION_REASON_INVALID_REQUEST;
   if(request.symbol_count<=0 ||
      request.symbol_count>KINGEA_CORRELATION_MAX_SYMBOLS ||
      request.override_count<0 ||
      request.override_count>KINGEA_CORRELATION_MAX_PAIRS ||
      request.expected_latest_close_time<=0)
      return;
   int expected_pairs=(request.symbol_count*(request.symbol_count-1))/2;
   if(expected_pairs>KINGEA_CORRELATION_MAX_PAIRS)
      return;

   string symbols[];
   ArrayResize(symbols,request.symbol_count);
   bool series_valid[KINGEA_CORRELATION_MAX_SYMBOLS];
   KingEACorrelationReason series_reason[KINGEA_CORRELATION_MAX_SYMBOLS];
   for(int i=0;i<request.symbol_count;i++)
     {
      symbols[i]=request.series[i].symbol_id;
      series_reason[i]=KingEACorrelationValidateSeries(request.series[i],
                                                       request.expected_latest_close_time);
      series_valid[i]=(series_reason[i]==KINGEA_CORRELATION_REASON_OK);
      if(symbols[i]=="")
         return;
      for(int j=0;j<i;j++)
         if(symbols[j]==symbols[i])
            return;
     }
   KingEACorrelationSortSymbols(symbols,request.symbol_count);

   int parents[KINGEA_CORRELATION_MAX_SYMBOLS];
   for(int i=0;i<request.symbol_count;i++)
      parents[i]=i;
   decision.cluster_known=true;
   decision.reason=KINGEA_CORRELATION_REASON_OK;
   decision.pair_count=0;
   decision.next_state.pair_count=0;

   for(int first_index=0;first_index<request.symbol_count;first_index++)
      for(int second_index=first_index+1;
          second_index<request.symbol_count;second_index++)
        {
         string first_symbol=symbols[first_index];
         string second_symbol=symbols[second_index];
         int first_source=-1,second_source=-1;
         for(int source=0;source<request.symbol_count;source++)
           {
            if(request.series[source].symbol_id==first_symbol)
               first_source=source;
            if(request.series[source].symbol_id==second_symbol)
               second_source=source;
           }
         int pair_index=decision.pair_count++;
         KingEACorrelationPairDecision pair={};
         pair.first_symbol=first_symbol;
         pair.second_symbol=second_symbol;
         pair.pair_key=KingEACorrelationPairKey(first_symbol,second_symbol);
         pair.static_override=KingEACorrelationHasOverride(request,pair.pair_key);
         int prior_index=KingEACorrelationFindPrior(prior,pair.pair_key);
         bool prior_active=(prior_index>=0 && prior.pairs[prior_index].edge_active);
         int prior_clean=(prior_index>=0 ?
                          prior.pairs[prior_index].release_clean_days : 0);
         datetime prior_day=(prior_index>=0 ?
                             prior.pairs[prior_index].last_evaluation_day : 0);

         if(first_source<0 || second_source<0 ||
            !series_valid[first_source] || !series_valid[second_source])
           {
            pair.reason=(first_source>=0 && !series_valid[first_source] ?
                         series_reason[first_source] :
                         (second_source>=0 ? series_reason[second_source] :
                          KINGEA_CORRELATION_REASON_INVALID_SERIES));
            pair.correlation_valid=false;
            pair.edge_active=true;
            pair.release_clean_days=0;
            decision.cluster_known=false;
            decision.healthy=false;
            decision.reason=pair.reason;
           }
         else
           {
            pair.reason=KingEACorrelationCalculatePair(request.series[first_source],
                                                       request.series[second_source],
                                                       pair.correlation_60,
                                                       pair.correlation_20);
            pair.correlation_valid=(pair.reason==KINGEA_CORRELATION_REASON_OK);
            if(!pair.correlation_valid)
              {
               pair.edge_active=true;
               pair.release_clean_days=0;
               decision.cluster_known=false;
               decision.healthy=false;
               decision.reason=pair.reason;
              }
            else if(pair.static_override ||
                    KingEACorrelationAtLeast(MathAbs(pair.correlation_60),0.60) ||
                    KingEACorrelationAtLeast(MathAbs(pair.correlation_20),0.70))
              {
               pair.edge_active=true;
               pair.release_clean_days=0;
              }
            else if(prior_active)
              {
               bool below_release=
                  !KingEACorrelationAtLeast(MathAbs(pair.correlation_60),0.45) &&
                  !KingEACorrelationAtLeast(MathAbs(pair.correlation_20),0.45);
               bool distinct_day=request.expected_latest_close_time>prior_day;
               pair.release_clean_days=(below_release && distinct_day ?
                                        prior_clean+1 : 0);
               pair.edge_active=(pair.release_clean_days<10);
               if(!pair.edge_active)
                  pair.release_clean_days=10;
              }
            else
              {
               pair.edge_active=pair.static_override;
               pair.release_clean_days=0;
              }
           }
         if(pair.static_override)
           {
            pair.edge_active=true;
            pair.release_clean_days=0;
           }
         decision.pairs[pair_index]=pair;
         KingEACorrelationPairState next_pair={};
         next_pair.pair_key=pair.pair_key;
         next_pair.edge_active=pair.edge_active;
         next_pair.release_clean_days=pair.release_clean_days;
         next_pair.last_evaluation_day=request.expected_latest_close_time;
         decision.next_state.pairs[pair_index]=next_pair;
         decision.next_state.pair_count++;
         if(pair.edge_active)
            KingEACorrelationUnion(parents,first_index,second_index);
        }

   decision.member_count=request.symbol_count;
   for(int i=0;i<request.symbol_count;i++)
     {
      int root=KingEACorrelationFindRoot(parents,i);
      string cluster_key=symbols[root];
      for(int j=0;j<request.symbol_count;j++)
         if(KingEACorrelationFindRoot(parents,j)==root &&
            StringCompare(symbols[j],cluster_key)<0)
            cluster_key=symbols[j];
      decision.members[i].symbol_id=symbols[i];
      decision.members[i].cluster_key=cluster_key;
      decision.members[i].cluster_known=decision.cluster_known;
     }
   if(request.symbol_count==1)
     {
      decision.cluster_known=series_valid[0];
      decision.healthy=series_valid[0];
      decision.reason=series_reason[0];
      decision.members[0].cluster_known=series_valid[0];
     }
   else if(decision.cluster_known)
      decision.healthy=true;
  }

#endif
