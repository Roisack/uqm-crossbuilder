#!/bin/bash
#
# This script builds UQM in a Virtual Machine for Windows
#
# Parameters:
#
# vanilla:
#       Builds Ur-Quan Masters vanilla code
#
# balance:
#       Builds Shiver's Balance Mod code with the retreat mod
#
#
#
# The script first creates a VirtualMachine and sets its properties
# then starts that machine and executes a build script inside it
# The produced executables and build logs are then found in the shared folder
#
#
# envvar: SHARED_DIR
#

export SHARED_DIR="shared_directory"
export IMAGE_NAME="uqm_crossbuilder.iso"

CURRENT_DIR=`pwd`
VANILLA_EXE="uqm.exe"
BALANCE_EXE="uqm-balance.exe"
BALANCE_RETREAT_EXE="uqm-balance-retreat.exe"
EFFECTS_PACK="balance-effects-unified.zip"
BUILD_VANILLA=false
BUILD_BMOD=false
BUILDSCRIPT_PATH="/home/user/build.sh"

if [ `echo $@ | grep "vanilla"` ]; then
    $BUILD_VANILLA = true
elif [ `echo $@ | grep "balance"` ]; then
    $BUILD_BMOD = true
else
    echo "You must specify build target: either vanilla or balance"
    exit 1
fi

cleanup ()
{
    echo "Shutting down the VM..."
    vboxmanage controlvm "UQM_crossbuilder_001" poweroff
    sleep 5
    echo "Deleting the VM"
    vboxmanage unregistervm "UQM_crossbuilder_001" -delete
    echo "Deleting the temporary hard drive"
    rm ./testhd.vdi
}

if [ ! -f ./$IMAGE_NAME ]; then
    echo "You need to have the live CD image $IMAGE_NAME in the current directory"
    exit 2
fi

echo "Found live CD image, all good"

if [ ! -d $SHARED_DIR ]; then
    echo "Shared dir does not exist. Creating it at $CURRENT_DIR/$SHARED_DIR"
    mkdir $SHARED_DIR
    if [ $? -ne 0 ]; then
        echo "Problem creating shared directory. Do you have permissions for this folder?"
        exit 3
    else
        echo "Shared directory created"
    fi
else
    echo "Shared dir already exists, verifying permissions"
    touch $SHARED_DIR/testfile
    if [ $? -ne 0 ]; then
        echo "Problem testing shared directory. Are the permissions in order?"
        exit 3
    else
        echo "All good"
    fi
fi

echo "Creating the Virtual Machine"
vboxmanage createvm --name "UQM_crossbuilder_001" --register
if [ $? -ne 0 ]; then
    echo "vboxmanage returned an error, canceling"
    vboxmanage unregistervm "UQM_crossbuilder_001" -delete
    exit 5
fi

# Give it a hard drive
vboxmanage createhd --filename ./testhd --size 1024
if [ $? -ne 0 ]; then
    echo "vboxmanage returned an error while creating a hard drive, canceling"
    rm ./testhd*
    vboxmanage unregistervm "UQM_crossbuilder_001" -delete
    exit 5
fi

# Give it a CD rom drive
vboxmanage storagectl "UQM_crossbuilder_001" --name "cdrom_drive" --add ide --controller PIIX4
if [ $? -ne 0 ]; then
    echo "vboxmanage returned an error while creating a cd rom drive, canceling"
    vboxmanage unregistervm "UQM_crossbuilder_001" -delete
    rm ./testhd*
    exit 5
fi

echo "Giving the live image to the Virtual Machine: $IMAGE_NAME"
vboxmanage storageattach "UQM_crossbuilder_001" --storagectl "cdrom_drive" --port 0 --device 0 --type dvddrive --medium $IMAGE_NAME
if [ $? -ne 0 ]; then
    echo "vboxmanage returned an error while inputting the live image, exiting"
    vboxmanage unregistervm "UQM_crossbuilder_001" -delete
    rm ./testhd*
fi

echo "Starting the Virtual Machine"
vboxmanage startvm "UQM_crossbuilder_001" --type headless
if [ $? -ne 0 ]; then
    echo "vboxmanage returned an error while starting the VM, canceling"
    cleanup
    exit 5
fi

echo "Waiting 10 seconds to make sure the boot menu has time to load"
sleep 10

# Send keyboard key "enter" to pass the boot menu
echo "Sending enter to boot menu"
vboxmanage controlvm "UQM_crossbuilder_001" keyboardputscancode 1c
if [ $? -ne 0 ]; then
    echo "vboxmanage returned an error while sending enter to the VM, canceling"
    cleanup
    exit 5
fi

echo "Waiting 30 seconds for the system to load"
echo "##################################################"
echo "After this the build will start and this terminal "
echo "won't report anything until the build is finished "
echo "If you want to follow the build you can run       "
echo "tail -f $CURRENT_DIR/$SHARED_DIR/build.log        "
echo "in another terminal to follow the build process   "
echo "The build probably takes a while, so wait warmly  "
echo "##################################################"

sleep 30
echo "Sending the build command to the Virtual Machine"
# Send a command to launch the build

if [ $BUILD_VANILLA ]; then
    vboxmanage guestcontrol execute "UQM_crossbuilder_001" "/bin/bash $BUILD_SCRIPT_PATH vanilla" --username "user"
    if [ $? -ne 0 ]; then
        echo "VirtualBox returned an error while sending the build command, canceling"
        cleanup
        exit 6
    else
        echo "All good"
        cleanup
    fi
elif [ $BUILD_BMOD ]; then
    vboxmanage guestcontrol execute "UQM_crossbuilder_001" "/bin/bash $BUILD_SCRIPT_PATH balance" --username "user"
    if [ $? -ne 0 ]; then
        echo "VirtualBox returned an error while sending the build command, canceling"
        cleanup
        exit 6
    else
        echo "All good"
        cleanup
    fi
else
    echo "Wait, you didn't specify which version of the game you want to build. This is either vanilla or balance"
    cleanup
    exit 7
fi

if [ $BUILD_VANILLA ]; then
    if [ -f $SHARED_DIR/$VANILLA_EXE]; then
        echo "Copying the binaries to the current directory"
        cp $SHARED_DIR/$VANILLA_EXE $CURRENT_DIR
    else
        echo "Binary not found. Something went wrong :("
    fi
fi

if [ $BUILD_BALANCE ]; then
    if [ -f $SHARED_DIR/$BALANCE_EXE ]; then
        echo "Copying the Balance Mod exe to current dir: $BALANCE_EXE"
        cp $SHARED_DIR/$BALANCE_EXE $CURRENT_DIR
    else
        echo "Balance Mod exe not found. Something went wrong :("
    fi
    if [ -f $SHARED_DIR/$BALANCE_RETREAT_EXE ]; then
        echo "Copying the balance mod retreat exe to the current dir: $BALANCE_RETREAT_EXE"
        cp $SHARED_DIR/$BALANCE_RETREAT_EXE $CURRENT_DIR
    else
        echo "Balance Mod Retreat exe not found. Something went wrong :("
    fi
    if [ -f $SHARED_DIR/$EFFECTS_PACK ]; then
        echo "Copying the effects pack to current dir: $EFFECTS_PACK"
        cp $SHARED_DIR/$EFFECTS_PACK $CURRENT_DIR
    else
        echo "Effecting pack not found. Something went wrong :("
    fi
fi

echo "All done!"
