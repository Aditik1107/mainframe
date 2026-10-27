import os

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(BASE_DIR, "data")
os.makedirs(DATA_DIR, exist_ok=True)

# Generate data/CUSTMAST.DAT
customers = [
    ('CUST000101', 'Aditi Prakash Kadam           ', 'aditi.kadam24@vit.edu         ', '+91-9209253813 ', 'A', '2024-01-15', '    '),
    ('CUST000102', 'Prof. Madhura Sanap           ', 'madhura.sanap@vit.edu         ', '+91-9766001130 ', 'A', '2023-06-10', '    '),
    ('CUST000103', 'Sharayu Abhijit Itkikar       ', 'sharayu.itkikar24@vit.edu     ', '+91-8446012951 ', 'A', '2024-02-20', '    '),
    ('CUST000104', 'Smruti Babruwan Gadave        ', 'smruti.1252040011@vit.edu     ', '+91-9511746098 ', 'A', '2024-03-01', '    '),
    ('CUST000105', 'Tata Consultancy Services     ', 'billing@tcs.com               ', '+91-2267789999 ', 'A', '2022-11-05', '    '),
    ('CUST000106', 'Infosys Cloud Labs            ', 'accounts@infosys.com          ', '+91-8028520261 ', 'A', '2023-04-12', '    '),
    ('CUST000107', 'Inactive Enterprise Corp      ', 'finance@dormant.com           ', '+91-1123456789 ', 'I', '2021-08-01', '    '),
    ('CUST000108', 'Wipro Technologies            ', 'pay@wipro.com                 ', '+91-8028440011 ', 'A', '2023-09-15', '    '),
    ('CUST000109', 'Tech Mahindra Research        ', 'sub@techmahindra.com          ', '+91-2066018100 ', 'A', '2024-01-08', '    '),
    ('CUST000110', 'Suspended Subscriber LLC      ', 'fraud@baduser.com             ', '+91-9876543210 ', 'S', '2023-12-01', '    '),
]

with open(os.path.join(DATA_DIR, 'CUSTMAST.DAT'), 'w', encoding='utf-8') as f:
    for c in customers:
        line = f'{c[0]:<10}{c[1]:<30}{c[2]:<30}{c[3]:<15}{c[4]:<1}{c[5]:<10}{c[6]:<4}\n'
        f.write(line)

# Generate data/PLANMAST.DAT
plans = [
    ('PLAN-001', 'Cloud Standard Tier      ', '000099900', 'M', 'A', '                '),
    ('PLAN-002', 'Enterprise Dedicated     ', '000499900', 'M', 'A', '                '),
    ('PLAN-003', 'Student Data Lab         ', '000049900', 'M', 'A', '                '),
    ('PLAN-004', 'Mainframe Batch Platinum ', '000999900', 'M', 'A', '                '),
    ('PLAN-099', 'Legacy Retired Plan      ', '000029900', 'M', 'I', '                '),
]

with open(os.path.join(DATA_DIR, 'PLANMAST.DAT'), 'w', encoding='utf-8') as f:
    for p in plans:
        line = f'{p[0]:<8}{p[1]:<25}{p[2]:<9}{p[3]:<1}{p[4]:<1}{p[5]:<16}\n'
        f.write(line)

# Generate data/SUBMAST.DAT
subs = [
    ('SUB1000001', 'CUST000101', 'PLAN-001', '2024-01-01', '2024-11-01', '010', 'A', '2026-10-01', '                  '),
    ('SUB1000002', 'CUST000102', 'PLAN-001', '2024-06-01', '2024-10-01', '004', 'A', '2026-10-01', '                  '),
    ('SUB1000003', 'CUST000103', 'PLAN-002', '2023-04-01', '2024-10-01', '018', 'A', '2026-10-01', '                  '),
    ('SUB1000004', 'CUST000104', 'PLAN-003', '2024-08-01', '2024-10-01', '002', 'A', '2026-10-01', '                  '),
    ('SUB1000005', 'CUST000105', 'PLAN-004', '2023-10-01', '2024-10-01', '012', 'A', '2026-10-01', '                  '),
    ('SUB1000006', 'CUST000109', 'PLAN-002', '2024-02-01', '2024-10-01', '008', 'A', '2026-10-01', '                  '),
    ('SUB1000007', 'CUST000107', 'PLAN-001', '2024-01-01', '2024-10-01', '009', 'A', '2026-10-01', '                  '),
    ('SUB1000008', 'CUST000106', 'PLAN-001', '2024-01-01', '2024-05-01', '005', 'C', '2026-10-01', '                  '),
    ('SUB1000009', 'CUST000108', 'PLAN-099', '2024-01-01', '2024-10-01', '009', 'A', '2026-10-01', '                  '),
    ('SUB1000010', 'CUST000110', 'PLAN-003', '2024-01-01', '2024-10-01', '009', 'A', '2026-10-01', '                  '),
]

with open(os.path.join(DATA_DIR, 'SUBMAST.DAT'), 'w', encoding='utf-8') as f:
    for s in subs:
        line = f'{s[0]:<10}{s[1]:<10}{s[2]:<8}{s[3]:<10}{s[4]:<10}{s[5]:<3}{s[6]:<1}{s[7]:<10}{s[8]:<18}\n'
        f.write(line)

# Generate data/PAYMENT.DAT
payments = [
    ('TXN202610011', 'SUB1000001', '000106094', '2026-10-02', 'UPI            ', 'SUCCESS   ', '              '),
    ('TXN202610012', 'SUB1000002', '000111988', '2026-10-02', 'CARD           ', 'SUCCESS   ', '              '),
    ('TXN202610013', 'SUB1000003', '000501400', '2026-10-02', 'NETBANKING     ', 'SUCCESS   ', '              '),
    ('TXN202610014', 'SUB1000004', '000058882', '2026-10-02', 'UPI            ', 'SUCCESS   ', '              '),
    ('TXN202610015', 'SUB1000005', '000500000', '2026-10-02', 'BANKTRANSFER   ', 'SUCCESS   ', '              '),
    ('TXN202610016', 'SUB1000006', '000530894', '2026-10-02', 'CARD           ', 'FAILED    ', '              '),
    ('TXN202610011', 'SUB1000001', '000106094', '2026-10-02', 'UPI            ', 'SUCCESS   ', '              '),
]

with open(os.path.join(DATA_DIR, 'PAYMENT.DAT'), 'w', encoding='utf-8') as f:
    for p in payments:
        line = f'{p[0]:<12}{p[1]:<10}{p[2]:<9}{p[3]:<10}{p[4]:<15}{p[5]:<10}{p[6]:<14}\n'
        f.write(line)

print("Master datasets generated.")
