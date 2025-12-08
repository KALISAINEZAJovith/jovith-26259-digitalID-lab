SET SERVEROUTPUT ON;

DECLARE
    v_request_id NUMBER;
    v_status_msg VARCHAR2(500);
    v_entity_id NUMBER;
    v_digital_id NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== TESTING SUBMIT_ACCESS_REQUEST ===');
    
    -- Get first active entity
    SELECT entity_id INTO v_entity_id
    FROM authorized_entities
    WHERE status = 'ACTIVE' AND ROWNUM = 1;
    
    -- Get first active digital ID
    SELECT digital_id INTO v_digital_id
    FROM digital_ids
    WHERE is_active = 'Y' AND ROWNUM = 1;
    
    DBMS_OUTPUT.PUT_LINE('Entity ID: ' || v_entity_id);
    DBMS_OUTPUT.PUT_LINE('Digital ID: ' || v_digital_id);
    
    -- Submit request
    submit_access_request(
        p_entity_id      => v_entity_id,
        p_digital_id     => v_digital_id,
        p_purpose        => 'Screenshot test - Account verification',
        p_data_category  => 'PERSONAL_INFO',
        p_ip_address     => '192.168.1.100',
        p_request_id     => v_request_id,
        p_status_message => v_status_msg
    );
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Request ID: ' || v_request_id);
    DBMS_OUTPUT.PUT_LINE('Status: ' || v_status_msg);
END;
/