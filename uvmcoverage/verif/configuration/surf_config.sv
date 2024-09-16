parameter NUMBER_OF_PARAMETERS = 37;

class surf_config extends uvm_object;

    uvm_active_passive_enum is_active = UVM_ACTIVE;

    randc int rand_test_init;
    int rand_test_num;

    // Slika, izlaz
    string img_properties[NUMBER_OF_PARAMETERS];
    string index32_gv_file[NUMBER_OF_PARAMETERS];
    string index16_gv_file[NUMBER_OF_PARAMETERS];
    string img32_file[NUMBER_OF_PARAMETERS];
    string img16_file[NUMBER_OF_PARAMETERS];
    string index32_file[NUMBER_OF_PARAMETERS];
    string index16_file[NUMBER_OF_PARAMETERS];
    string num;

    int fracr_upper = 0;
    int fracr_lower = 0;
    int fracc_upper = 0;
    int fracc_lower = 0;
    int spacing_upper = 0;
    int spacing_lower = 0;
    int i_cose_upper = 0;
    int i_cose_lower = 0;
    int i_sine_upper = 0;
    int i_sine_lower = 0;
    int iradius = 0;
    int iy = 0;
    int ix = 0;
    int step = 0;
    int scale = 0;

    int fd = 0;
    int i = 0;
    int tmp;

    int index32_gv_arr[$];
    int index16_gv_arr[$];
    int coverage_goal_cfg;

    int img32_data[$];
    int img16_data[$];

    int index32_data[$];
    int index16_data[$];

    `uvm_object_utils_begin(surf_config)
        `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "surf_config");
        super.new(name);

        // Randomizacija u konstruktoru
        rand_test_num = $urandom_range(0, NUMBER_OF_PARAMETERS - 1);

        img_properties[0] = "../../../../../files\/parameters_input.txt";
        index32_gv_file[0] = "../../../../../golden_vectors\/index_upper_32.txt";
        index16_gv_file[0] = "../../../../../golden_vectors\/index_lower_16.txt";
        img32_file[0] = "../../../../../files/pixels1D_32\/pixels1D_upper32.txt";
        img16_file[0] = "../../../../../files/pixels1D_16\/pixels1D_lower16.txt";
        index32_file[0] = "../../../../../files\/index_upper_32.txt";
        index16_file[0] = "../../../../../files\/index_lower_16.txt";

        // Loop initialization for all parameters
        for (int j = 1; j < NUMBER_OF_PARAMETERS; j++)
        begin
            num.itoa(j);
            img_properties[j] = {"../../../../../files\/parameters_input",num,".txt"};
            index32_gv_file[j] = {"../../../../../golden_vectors\/index_upper_32_",num,".txt"};
            index16_gv_file[j] = {"../../../../../golden_vectors\/index_lower_16_",num,".txt"};
            img32_file[j] = {"../../../../../files\/pixels1D_upper_32_",num,".txt"};
            img16_file[j] = {"../../../../../files\/pixels1D_lower_16_",num,".txt"};
            index32_file[j] = {"../../../../../files\/index_upper_32_",num,".txt"};
            index16_file[j] = {"../../../../../files\/index_lower_16_",num,".txt"};
        end

        $display("Randomized rand_test_num : %d", rand_test_num);
    endfunction

    function void extracting_data();
        // Proverite dostupnost fajla pre otvaranja
        fd = $fopen(img_properties[rand_test_num], "r");
        if (fd == 0) begin
            `uvm_warning("File Error", $sformatf("File %s could not be opened. Using default file.", img_properties[rand_test_num]));
            rand_test_num = 0;
            fd = $fopen(img_properties[rand_test_num], "r");
        end
    
    if (fd != 0) begin
        `uvm_info(get_name(), $sformatf("Successfully opened %s", img_properties[rand_test_num]), UVM_LOW);
        // Nastavak obrade fajla
        $fscanf(fd, "%d\n", fracr_upper);
        $fscanf(fd, "%d\n", fracr_lower);
        $fscanf(fd, "%d\n", fracc_upper);
        $fscanf(fd, "%d\n", fracc_lower);
        $fscanf(fd, "%d\n", spacing_upper);
        $fscanf(fd, "%d\n", spacing_lower);
        $fscanf(fd, "%d\n", i_cose_upper);
        $fscanf(fd, "%d\n", i_cose_lower);
        $fscanf(fd, "%d\n", i_sine_upper);
        $fscanf(fd, "%d\n", i_sine_lower);
        $fscanf(fd, "%d\n", iradius);
        $fscanf(fd, "%d\n", iy);
        $fscanf(fd, "%d\n", ix);
        $fscanf(fd, "%d\n", step);
        $fscanf(fd, "%d\n", scale);
    end else begin
        `uvm_error("File Error", "Could not open any file, even the default one.");
    end
    
    $fclose(fd);
	
	
	 //**************************   FUNKCIJA ZA UCITAVANJE ZLATNIH VEKTORA    **************************//
    //**************************        ZA INXEDE 32 I 16           **************************//
	
	        fd = $fopen(index32_gv_file[rand_test_num],"r");
        if(fd) begin 
            `uvm_info(get_name(), $sformatf("Successfully opened index32_gv file"),UVM_LOW)
            while(!$feof(fd)) 
            begin
                $fscanf(fd ,"%d\n",tmp);
                index32_gv_arr.push_back(tmp);
            end
        end
        else begin
            `uvm_info(get_name(), $sformatf(index32_gv_file),UVM_LOW)    
        end
        $display("Index32 golden vectors stored to index32_gv_arr successfully %d",rand_test_num);
        $fclose(fd);

        fd = $fopen(index16_gv_file[rand_test_num],"r");
        if(fd) begin 
            `uvm_info(get_name(), $sformatf("Successfully opened index16_gv_file"),UVM_LOW)
            while(!$feof(fd)) 
            begin
                $fscanf(fd ,"%d\n",tmp);
                index16_gv_arr.push_back(tmp);
            end
        end
        else begin
            `uvm_info(get_name(), $sformatf("Error opening index16_gv_file"),UVM_LOW)    
        end
        $display("Index16 golden vectors stored to index16_gv_arr successfully %d",rand_test_num);
        $fclose(fd);

        ///////coverage_goal_cfg = rho * HALF_THETA;
	
	
	 //**************************   READING FROM AN IMAGE FILE    **************************//


        img32_data.delete();

        fd = $fopen(img32_file[rand_test_num],"r");
        if(fd) begin 
            `uvm_info(get_name(), $sformatf("Successfully opened img32_file %d", rand_test_num),UVM_LOW)
            while(!$feof(fd)) 
            begin
                $fscanf(fd ,"%d\n",tmp);
                img32_data.push_back(tmp);
            end
        end
        else begin
            `uvm_info(get_name(), $sformatf("Error opening pixels1d_32.txt"),UVM_HIGH)    
        end
        $fclose(fd);

        img16_data.delete();

        fd = $fopen(img16_file[rand_test_num],"r");
        if(fd) begin 
            `uvm_info(get_name(), $sformatf("Successfully opened img16_file %d", rand_test_num),UVM_LOW)
            while(!$feof(fd)) 
            begin
                $fscanf(fd ,"%d\n",tmp);
                img16_data.push_back(tmp);
            end
        end
        else begin
            `uvm_info(get_name(), $sformatf("Error opening pixels1d_16.txt"),UVM_HIGH)    
        end
        $fclose(fd);


// ************************   READING FROM A INDEX32 FILE ********************************//
    

        index32_data.delete();

        fd = $fopen(index32_file[rand_test_num],"r");
        if(fd) begin 
            `uvm_info(get_name(), $sformatf("Successfully opened index32_file"),UVM_LOW)

            while(!$feof(fd)) 
            begin
                $fscanf(fd ,"%d\n",tmp);
                index32_data.push_back(tmp);
            end    
        end
        else begin
            `uvm_info(get_name(), $sformatf("Error opening index32.txt"),UVM_LOW)    
        end
        $fclose(fd);


		// ************************   READING FROM A INDEX16 FILE ********************************//
    

        index16_data.delete();

        fd = $fopen(index16_file[rand_test_num],"r");
        if(fd) begin 
            `uvm_info(get_name(), $sformatf("Successfully opened index16_file"),UVM_LOW)

            while(!$feof(fd)) 
            begin
                $fscanf(fd ,"%d\n",tmp);
                index16_data.push_back(tmp);
            end    
        end
        else begin
            `uvm_info(get_name(), $sformatf("Error opening index16.txt"),UVM_LOW)    
        end
        $fclose(fd);
		
    endfunction : extracting_data
endclass : surf_config

        