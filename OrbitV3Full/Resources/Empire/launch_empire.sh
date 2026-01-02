#!/bin/bash
# Empire Launch Script - Start all 15 endeavors
echo "🚀 JLow Empire - Launching All Endeavors"
echo "========================================="

EMPIRE_DIR="/Users/jlow/Desktop/Empire"

# Array of endeavors with ports
declare -A endeavors=(
    ["01_VirtualPullUp"]=5001
    ["02_LilBitFactory"]=5002
    ["03_PhoneReceptionist"]=5003
    ["04_LandingPageGen"]=5004
    ["05_DroneTech"]=5005
    ["06_FinanceAdvisor"]=5006
    ["07_ContractAnalyzer"]=5007
    ["08_MealPlanner"]=5008
    ["09_WritingAssistant"]=5009
    ["10_JobTracker"]=5010
    ["11_ResumeOptimizer"]=5011
    ["12_ClipGenerator"]=5012
    ["13_MCPMarketplace"]=5013
    ["14_ColdEmailer"]=5014
    ["15_SupportAgent"]=5015
)

# Check if port is in use
check_port() {
    lsof -i :$1 > /dev/null 2>&1
    return $?
}

# Launch function
launch_endeavor() {
    local name=$1
    local port=$2
    local dir="$EMPIRE_DIR/$name"
    
    if [ ! -d "$dir" ]; then
        echo "⚠️  $name: Directory not found"
        return
    fi
    
    if check_port $port; then
        echo "⏭️  $name: Already running on port $port"
        return
    fi
    
    if [ -f "$dir/app.py" ]; then
        echo "🚀 $name: Launching on port $port..."
        cd "$dir"
        
        # Create venv if needed
        if [ ! -d "venv" ]; then
            python3 -m venv venv
        fi
        
        source venv/bin/activate
        pip install -r requirements.txt --quiet 2>/dev/null
        
        # Launch in background
        nohup python app.py > "$dir/app.log" 2>&1 &
        echo $! > "$dir/app.pid"
        
        deactivate
        echo "✅ $name: Started (PID: $(cat $dir/app.pid))"
    else
        echo "⚠️  $name: No app.py found"
    fi
}

# Stop function
stop_endeavor() {
    local name=$1
    local dir="$EMPIRE_DIR/$name"
    
    if [ -f "$dir/app.pid" ]; then
        kill $(cat "$dir/app.pid") 2>/dev/null
        rm "$dir/app.pid"
        echo "🛑 $name: Stopped"
    fi
}

# Main
case "${1:-start}" in
    start)
        for name in "${!endeavors[@]}"; do
            launch_endeavor "$name" "${endeavors[$name]}"
        done
        echo ""
        echo "🎉 Empire Launch Complete!"
        echo "Dashboard: http://localhost:5000"
        ;;
    stop)
        for name in "${!endeavors[@]}"; do
            stop_endeavor "$name"
        done
        echo "🛑 All endeavors stopped"
        ;;
    status)
        echo "Empire Status:"
        for name in "${!endeavors[@]}"; do
            port="${endeavors[$name]}"
            if check_port $port; then
                echo "✅ $name: Running on port $port"
            else
                echo "❌ $name: Stopped"
            fi
        done
        ;;
    *)
        echo "Usage: $0 {start|stop|status}"
        ;;
esac
