import hashlib
import json
import struct
import unittest
import zipfile
from fractions import Fraction
from pathlib import Path
from governance.review.offline_v3_ieee754_rounding_cell_20260929 import ieee754_price_grid as grid

ROOT=Path(__file__).resolve().parents[1]
RUNTIME=ROOT/'governance/review/v5_retained_custodianship_long_runtime_20260928/RUNTIME_REVIEW_BUNDLE.zip'
PROFILE=ROOT/'governance/review/final_offline_v3_packet_binding_20260928/extracted_v5_final/tester_profile.json'
SUCCESSOR=ROOT/'governance/review/offline_v3_ieee754_rounding_cell_20260929/review_successor_decision_a_evidence.py'
ACCEPTED=ROOT/'research_pipeline/decision_a_evidence.py'

# A power-of-two rational always has a terminating decimal expansion.
def exact_text(x):
    n,d=x.numerator,x.denominator
    places=d.bit_length()-1
    assert d==1<<places
    scaled=abs(n)*5**places
    whole,frac=divmod(scaled,10**places)
    out=str(whole)+(('.'+str(frac).zfill(places)) if places else '')
    return ('-' if n<0 else '')+out

class ExactRoundingCellTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with zipfile.ZipFile(RUNTIME) as z:
            cls.capture=z.read('native_spool/new/NATIVE_COST_0_F810E6BA338E80C7390C4B1F49E49953589C629AB11A6A66743DEE5434BB94FA.evidence')
        cls.profile=json.loads(PROFILE.read_bytes())
        cls.auth=grid.authenticated_capture_prices(cls.capture)

    def test_01_accepted_source_preserved(self):
        self.assertEqual(hashlib.sha256(ACCEPTED.read_bytes()).hexdigest().upper(),'B9D7CBB12185BCDFAF318D483AA9D234644303F48F75EF50C6E56B800DC2132F')
        self.assertEqual(hashlib.sha256((ROOT/'research_pipeline/native_conformance_control.py').read_bytes()).hexdigest().upper(),'6DE99C5054311AA0D745EA386DFE617F167130FDC10D97EE545867F348694491')
        s=SUCCESSOR.read_bytes()
        self.assertIn(b'ORIGINAL_PRICE_OFF_GRID',s)
        self.assertIn(b'DEAL_PRECISION_INVALID',s)

    def test_02_exact_current_capture_authentication(self):
        self.assertEqual(len(self.capture),10542)
        self.assertEqual(hashlib.sha256(self.capture).hexdigest().upper(),grid.CAPTURE_SHA256)
        self.assertEqual(self.auth,dict(P0='1267.6700000000000728',S0='600.0000000000000000',deal_prices=['1267.6700000000000728','1218.7999999999999546','1218.0000000000000000']))

    def test_03_current_entry_and_reduction_bits_and_cells(self):
        for value,bits,point in [('1267.6700000000000728',0x4093CEAE147AE148,Fraction(126767,100)),('1218.7999999999999546',0x40930B3333333333,Fraction(121880,100))]:
            p=grid.grid_cell_proof(value,'.01')
            self.assertTrue(p['valid'])
            self.assertEqual(p['bits'],bits)
            self.assertEqual(p['grid'],point)
            self.assertLess(p['lower'],p['retained'])
            self.assertLess(p['retained'],p['upper'])
            self.assertNotEqual(p['retained']%Fraction(1,100),0)
            self.assertEqual(struct.unpack('>Q',struct.pack('>d',float(point)))[0],bits)

    def test_04_exact_close_and_stop(self):
        for value,field in [('1218.0000000000000000','DEAL_PRICE'),('600.0000000000000000','S0')]:
            self.assertTrue(grid.grid_cell_proof(value,'.01')['valid'])
            provenance={field:value}
            self.assertTrue(grid.governed_native_price_valid(value,'.01',self.profile,provenance,field))

    def test_05_all_current_deal_gates_and_originals(self):
        for key in ('P0','S0'):
            self.assertTrue(grid.governed_native_price_valid(self.auth[key],'.01',self.profile,self.auth,key))
        for price in self.auth['deal_prices']:
            self.assertTrue(grid.governed_native_price_valid(price,'.01',self.profile,{'DEAL_PRICE':price},'DEAL_PRICE'))

    def test_06_subtick_and_midtick_rejections(self):
        for value in ('1267.6740000000000000','1267.6760000000000000','1218.8040000000000000'):
            self.assertFalse(grid.grid_cell_proof(value,'.01')['valid'])
        for value in ('1267.6750000000000000','1218.8050000000000000'):
            with self.assertRaisesRegex(ValueError,'TICK_INDEX_MIDPOINT'):
                grid.grid_cell_proof(value,'.01')

    def test_07_neighbor_one_ulp_and_boundaries_reject(self):
        for value in (self.auth['P0'],self.auth['deal_prices'][1]):
            p=grid.grid_cell_proof(value,'.01')
            for other in (grid.binary64_bits_to_fraction(p['bits']-1),grid.binary64_bits_to_fraction(p['bits']+1),p['lower'],p['upper']):
                self.assertFalse(grid.grid_cell_proof(exact_text(other),'.01')['valid'])

    def test_08_bad_text_and_ticks_reject(self):
        for value in ('','NaN','nan','Infinity','-Infinity','abc'):
            with self.assertRaises(ValueError): grid.grid_cell_proof(value,'.01')
        for tick in ('0','-.01','NaN',''):
            with self.assertRaises(ValueError): grid.grid_cell_proof(self.auth['P0'],tick)
        self.assertFalse(grid.grid_cell_proof(self.auth['P0'],'.02')['valid'])

    def test_09_authenticity_and_convention_reject(self):
        with self.assertRaisesRegex(ValueError,'NATIVE_CAPTURE_PIN_MISMATCH'):
            grid.authenticated_capture_prices(self.capture[:-1]+b'X')
        self.assertFalse(grid.governed_native_price_valid(self.auth['P0'],'.01',self.profile,{},'P0'))
        self.assertFalse(grid.governed_native_price_valid('1267.6700000000000729','.01',self.profile,self.auth,'P0'))
        self.assertFalse(grid.governed_native_price_valid(self.auth['P0'],'.02',self.profile,self.auth,'P0'))
        wrong=dict(self.profile,symbol='WRONG')
        self.assertFalse(grid.governed_native_price_valid(self.auth['P0'],'.01',wrong,self.auth,'P0'))

    def test_10_host_crosscheck_and_ties_even(self):
        for tick in ('.001','.01','.1','.25','.5'):
            t=grid.exact_decimal(tick)
            for k in (1,7,1218,126767,10**9):
                value=t*k
                bits=grid.positive_fraction_to_binary64_bits(value)
                host=struct.unpack('>Q',struct.pack('>d',float(value)))[0]
                self.assertEqual(bits,host)
                self.assertEqual(grid.binary64_bits_to_fraction(bits),Fraction.from_float(float(value)))
        for value in ('-12.25','-.01','-0.0001'):
            self.assertLess(grid.exact_decimal(value),0)
        with self.assertRaises(ValueError): grid.positive_fraction_to_binary64_bits(Fraction(-1))
        self.assertEqual(grid.positive_fraction_to_binary64_bits(Fraction(1,1<<1074)),1)
        self.assertEqual(grid.positive_fraction_to_binary64_bits(Fraction(3,1<<1075)),2)

if __name__=='__main__': unittest.main()

