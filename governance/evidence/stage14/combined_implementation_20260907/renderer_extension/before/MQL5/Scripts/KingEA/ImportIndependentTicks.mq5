#property copyright "KingEA"
#property version   "1.00"
#property script_show_inputs
#property description "RETIRED for KingEA strategy use; retained only as an unauthorized audit artifact."
#property description "This script cannot place; modify; or close trades."

input bool   InpExternalVenueImportAuthorized = false;
input string InpOriginSymbol = "ETHUSD.s";
input string InpCustomSymbol = "KINGEA_ETHUSD_I1";
input string InpCustomPath = "KingEA\\Independent";
input string InpDataDirectory = "KingEA\\independent\\KINGEA-ETH-INDEPENDENT-V1";
input int InpBatchSize = 100000;

bool FlushBatch(MqlTick &ticks[],int &count,long &total,long &last_time_msc)
  {
   if(count<=0)
      return true;
   ArrayResize(ticks,count);
   ResetLastError();
   int added=CustomTicksAdd(InpCustomSymbol,ticks,(uint)count);
   if(added!=count)
     {
      PrintFormat("KingEA import failed: CustomTicksAdd added %d/%d; error=%d",added,count,GetLastError());
      return false;
     }
   total+=added;
   last_time_msc=ticks[count-1].time_msc;
   count=0;
   ArrayResize(ticks,InpBatchSize);
   return true;
  }

bool ImportTickFile(const string filename,long &total,long &last_time_msc)
  {
   string path=InpDataDirectory+"\\"+filename;
   int handle=FileOpen(path,FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
   if(handle==INVALID_HANDLE)
     {
      PrintFormat("KingEA import failed: cannot open %s; error=%d",path,GetLastError());
      return false;
     }

   // Consume five-column header.
   for(int i=0;i<5 && !FileIsEnding(handle);i++)
      FileReadString(handle);

   MqlTick ticks[];
   ArrayResize(ticks,InpBatchSize);
   int count=0;
   long file_rows=0;
   while(!FileIsEnding(handle))
     {
      string time_text=FileReadString(handle);
      if(StringLen(time_text)==0)
         break;
      long time_msc=(long)StringToInteger(time_text);
      double bid=StringToDouble(FileReadString(handle));
      double ask=StringToDouble(FileReadString(handle));
      double last=StringToDouble(FileReadString(handle));
      double volume_real=StringToDouble(FileReadString(handle));
      if(time_msc<=0 || bid<=0.0 || ask<=bid || last<=0.0 || volume_real<=0.0 ||
         (last_time_msc>0 && time_msc<last_time_msc))
        {
         PrintFormat("KingEA import failed: invalid or unordered row %I64d in %s",file_rows+1,filename);
         FileClose(handle);
         return false;
        }

      ZeroMemory(ticks[count]);
      ticks[count].time_msc=time_msc;
      ticks[count].time=(datetime)(time_msc/1000);
      ticks[count].bid=bid;
      ticks[count].ask=ask;
      ticks[count].last=last;
      ticks[count].volume_real=volume_real;
      ticks[count].flags=0;
      count++;
      file_rows++;
      if(count>=InpBatchSize && !FlushBatch(ticks,count,total,last_time_msc))
        {
         FileClose(handle);
         return false;
        }
     }
   FileClose(handle);
   if(!FlushBatch(ticks,count,total,last_time_msc))
      return false;
   PrintFormat("KingEA imported %I64d rows from %s",file_rows,filename);
   return true;
  }

void OnStart()
  {
   if(!InpExternalVenueImportAuthorized)
     {
      Print("KingEA import refused: external-venue custom symbols are not authorized for strategy research or validation.");
      return;
     }
   if(InpBatchSize<1000 || InpBatchSize>1000000)
     {
      Print("KingEA import failed: InpBatchSize must be 1000..1000000.");
      return;
     }
   if(!SymbolSelect(InpOriginSymbol,true))
     {
      PrintFormat("KingEA import failed: origin symbol %s unavailable.",InpOriginSymbol);
      return;
     }

   bool is_custom=false;
   bool exists=SymbolExist(InpCustomSymbol,is_custom);
   if(exists && !is_custom)
     {
      Print("KingEA import refused: target name belongs to a broker symbol.");
      return;
     }
   if(!exists && !CustomSymbolCreate(InpCustomSymbol,InpCustomPath,InpOriginSymbol))
     {
      PrintFormat("KingEA import failed: CustomSymbolCreate error=%d",GetLastError());
      return;
     }
   if(!SymbolSelect(InpCustomSymbol,true))
     {
      PrintFormat("KingEA import failed: cannot select custom symbol; error=%d",GetLastError());
      return;
     }

   MqlTick existing[];
   if(CopyTicks(InpCustomSymbol,existing,COPY_TICKS_ALL,0,1)>0)
     {
      Print("KingEA import refused: custom symbol already contains ticks. Use a new versioned symbol name.");
      return;
     }

   string manifest_path=InpDataDirectory+"\\mt5_import_manifest.csv";
   int manifest=FileOpen(manifest_path,FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
   if(manifest==INVALID_HANDLE)
     {
      PrintFormat("KingEA import failed: cannot open %s; error=%d",manifest_path,GetLastError());
      return;
     }
   for(int i=0;i<6 && !FileIsEnding(manifest);i++)
      FileReadString(manifest);

   long total=0;
   long last_time_msc=0;
   int files=0;
   bool ok=true;
   while(!FileIsEnding(manifest))
     {
      string filename=FileReadString(manifest);
      if(StringLen(filename)==0)
         break;
      string month=FileReadString(manifest);
      string first_time=FileReadString(manifest);
      string last_time=FileReadString(manifest);
      string expected_rows=FileReadString(manifest);
      string sha256=FileReadString(manifest);
      PrintFormat("KingEA importing %s month=%s expected_rows=%s sha256=%s",filename,month,expected_rows,sha256);
      if(!ImportTickFile(filename,total,last_time_msc))
        {
         ok=false;
         break;
        }
      files++;
     }
   FileClose(manifest);

   if(!ok)
     {
      Print("KingEA independent tick import halted. The partially imported custom symbol must not be used.");
      return;
     }
   PrintFormat("KingEA independent tick import complete: symbol=%s files=%d ticks=%I64d last_time_msc=%I64d",
               InpCustomSymbol,files,total,last_time_msc);
   Print("This custom symbol is non-broker synthetic evidence and cannot be used for live trading.");
  }
