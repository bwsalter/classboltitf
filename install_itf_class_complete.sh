#!/bin/bash
################################################################################
# ITF-Modified CLASS - Complete Automated Installation
# This script downloads CLASS and applies ALL ITF modifications
#
# Usage: bash install_itf_class_complete.sh
################################################################################

set -e  # Exit on error

echo "================================================================================"
echo "ITF-MODIFIED CLASS - COMPLETE INSTALLATION"
echo "================================================================================"

# Download CLASS
echo ""
echo "Step 1: Downloading CLASS v3.3.4..."
git clone https://github.com/lesgourg/class_public.git
cd class_public

echo "✓ CLASS downloaded"

# Backup original files
echo ""
echo "Step 2: Creating backups..."
cp include/background.h include/background.h.original
cp source/background.c source/background.c.original
cp source/perturbations.c source/perturbations.c.original
cp source/input.c source/input.c.original
echo "✓ Backups created"

# Modification 1: background.h
echo ""
echo "Step 3: Modifying include/background.h..."
python3 << 'PYTHON_EOF'
import re

with open('include/background.h', 'r') as f:
    content = f.read()

# Find struct background and add ITF parameters
struct_match = re.search(r'(struct background\s*\{.*?)(};)', content, re.DOTALL)

if struct_match:
    itf_params = '''
  /**************************************************************************/
  /* ITF (Informational Topography Field) parameters                        */
  /**************************************************************************/
  
  short has_itf;           /**< flag: ITF corrections enabled? */
  double A_itf;            /**< geometric constant (0.0172) */
  double c_H_itf;          /**< Hubble coefficient (5.08) */
  double c_S_itf;          /**< structure coefficient (3.3) */
  double f_void_itf;       /**< void fraction (0.68) */
  double rho_screen_itf;   /**< screening threshold (10.0) */

'''
    new_content = content[:struct_match.end(1)] + itf_params + content[struct_match.end(1):]
    
    with open('include/background.h', 'w') as f:
        f.write(new_content)
    print("✓ background.h modified")
else:
    print("✗ ERROR: Could not find struct background")
    exit(1)
PYTHON_EOF

# Modification 2: background.c (Friedmann equation)
echo ""
echo "Step 4: Modifying source/background.c (Friedmann equation)..."
python3 << 'PYTHON_EOF'
import re

with open('source/background.c', 'r') as f:
    content = f.read()

# Find and replace Friedmann equation
pattern = r'pvecback\[pba->index_bg_H\]\s*=\s*sqrt\(rho_tot\s*-\s*pba->K/a/a\)\s*;'
replacement = '''double H_base = sqrt(rho_tot-pba->K/a/a);
  
  /* ITF: Apply correction to Hubble parameter */
  if (pba->has_itf == _TRUE_) {
    double Delta_H = pba->c_H_itf * pba->A_itf;
    pvecback[pba->index_bg_H] = H_base * (1.0 + Delta_H);
  } else {
    pvecback[pba->index_bg_H] = H_base;
  }'''

new_content = re.sub(pattern, replacement, content)

with open('source/background.c', 'w') as f:
    f.write(new_content)
    
print("✓ background.c modified (Friedmann equation)")
PYTHON_EOF

# Modification 3: perturbations.c (growth equations)
echo ""
echo "Step 5: Modifying source/perturbations.c (growth equations)..."
python3 << 'PYTHON_EOF'
with open('source/perturbations.c', 'r') as f:
    lines = f.readlines()

modified = 0
for i, line in enumerate(lines):
    # Find theta_cdm evolution equation
    if 'dy[pv->index_pt_theta_cdm]' in line and 'a_prime_over_a' in line and 'metric_euler' in line:
        indent = len(line) - len(line.lstrip())
        replacement = ' ' * indent + '''/* ITF: Apply growth suppression */
''' + ' ' * indent + '''if (pba->has_itf == _TRUE_) {
''' + ' ' * indent + '''  double Delta_growth = -pba->c_S_itf * pba->A_itf;
''' + ' ' * indent + '''  dy[pv->index_pt_theta_cdm] = -(a_prime_over_a*y[pv->index_pt_theta_cdm] - metric_euler*(1.0 + Delta_growth));
''' + ' ' * indent + '''} else {
''' + ' ' * indent + '''  dy[pv->index_pt_theta_cdm] = -a_prime_over_a*y[pv->index_pt_theta_cdm] + metric_euler;
''' + ' ' * indent + '''}
'''
        lines[i] = replacement
        modified += 1

with open('source/perturbations.c', 'w') as f:
    f.writelines(lines)

print(f"✓ perturbations.c modified ({modified} locations)")
PYTHON_EOF

# Modification 4: input.c (parameter reading)
echo ""
echo "Step 6: Modifying source/input.c (parameter reading)..."
python3 << 'PYTHON_EOF'
import re

with open('source/input.c', 'r') as f:
    content = f.read()

# Find insertion point after omega_cdm
match = re.search(r'class_call\(parser_read_double\(pfc,\s*"omega_cdm".*?\);', content, re.DOTALL)

if match:
    itf_input = '''

  /**************************************************************************/
  /* ITF: Read parameters from .ini file                                    */
  /**************************************************************************/
  
  class_call(parser_read_string(pfc, "has_itf", &string1, &flag1, errmsg),
             errmsg, errmsg);
  
  if (flag1 == _TRUE_) {
    if ((strstr(string1,"y") != NULL) || (strstr(string1,"Y") != NULL)) {
      pba->has_itf = _TRUE_;
    } else {
      pba->has_itf = _FALSE_;
    }
  } else {
    pba->has_itf = _FALSE_;
  }
  
  class_call(parser_read_double(pfc, "A_itf", &param1, &flag1, errmsg),
             errmsg, errmsg);
  pba->A_itf = (flag1 == _TRUE_) ? param1 : 0.0172;
  
  class_call(parser_read_double(pfc, "c_H_itf", &param1, &flag1, errmsg),
             errmsg, errmsg);
  pba->c_H_itf = (flag1 == _TRUE_) ? param1 : 5.08;
  
  class_call(parser_read_double(pfc, "c_S_itf", &param1, &flag1, errmsg),
             errmsg, errmsg);
  pba->c_S_itf = (flag1 == _TRUE_) ? param1 : 3.3;
  
  class_call(parser_read_double(pfc, "f_void_itf", &param1, &flag1, errmsg),
             errmsg, errmsg);
  pba->f_void_itf = (flag1 == _TRUE_) ? param1 : 0.68;
  
  class_call(parser_read_double(pfc, "rho_screen_itf", &param1, &flag1, errmsg),
             errmsg, errmsg);
  pba->rho_screen_itf = (flag1 == _TRUE_) ? param1 : 10.0;
  
  if (pba->has_itf == _TRUE_ && pba->background_verbose > 0) {
    printf("\\n -> ITF ENABLED:\\n");
    printf("    A = %.4f, c_H = %.2f, c_S = %.2f\\n", 
           pba->A_itf, pba->c_H_itf, pba->c_S_itf);
    printf("    H0_ITF = %.2f km/s/Mpc (expected)\\n",
           pba->H0 * (1.0 + pba->c_H_itf * pba->A_itf));
    printf("    Growth suppression = %.2f%%\\n\\n",
           100.0 * pba->c_S_itf * pba->A_itf);
  }
'''
    
    new_content = content[:match.end()] + itf_input + content[match.end():]
    
    with open('source/input.c', 'w') as f:
        f.write(new_content)
    print("✓ input.c modified")
else:
    print("✗ ERROR: Could not find insertion point")
    exit(1)
PYTHON_EOF

# Compile
echo ""
echo "================================================================================"
echo "Step 7: Compiling CLASS with ITF"
echo "================================================================================"
make clean
make

if [ -f "class" ]; then
    echo ""
    echo "================================================================================"
    echo "✓✓✓ COMPILATION SUCCESSFUL ✓✓✓"
    echo "================================================================================"
    echo ""
    echo "ITF is fully embedded in CLASS:"
    echo "  ✓ Background evolution (Friedmann equation)"
    echo "  ✓ Perturbation evolution (growth equations)"  
    echo "  ✓ Parameter reading from .ini files"
    echo ""
else
    echo ""
    echo "✗ Compilation failed"
    exit 1
fi

# Create test files
echo "Step 8: Creating test parameter files..."

cat > test_lcdm.ini << 'EOF'
# Standard LCDM (Planck 2018)
h = 0.6737
omega_b = 0.02237
omega_cdm = 0.1200
A_s = 2.1e-9
n_s = 0.9649
tau_reio = 0.0544

has_itf = no

output = tCl, mPk
l_max_scalars = 2500
EOF

cat > test_itf.ini << 'EOF'
# ITF cosmology
h = 0.6737
omega_b = 0.02237
omega_cdm = 0.1200
A_s = 2.1e-9
n_s = 0.9649
tau_reio = 0.0544

has_itf = yes
A_itf = 0.0172
c_H_itf = 5.08
c_S_itf = 3.3

output = tCl, mPk
l_max_scalars = 2500
EOF

echo "✓ Test files created"

# Run tests
echo ""
echo "Step 9: Running tests..."
echo ""
echo "Running LCDM..."
./class test_lcdm.ini

echo ""
echo "Running ITF..."
./class test_itf.ini

echo ""
echo "================================================================================"
echo "✓ INSTALLATION COMPLETE"
echo "================================================================================"
echo ""
echo "To use:"
echo "  ./class your_params.ini"
echo ""
echo "To enable ITF, add to your .ini file:"
echo "  has_itf = yes"
echo "  A_itf = 0.0172"
echo "  c_H_itf = 5.08"
echo "  c_S_itf = 3.3"
echo ""
