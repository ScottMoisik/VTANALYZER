function [priors] = load_second_order_landmarks(xmlTemplateFileName, landmarks)
%=========================================================================
%PARSE XML TEMPLATE
%=========================================================================
%Parse XML template to discover what landmarks to load and how they are defined
template = xmlread(fullfile(pwd, xmlTemplateFileName));
root = template.getDocumentElement;
%type(fullfile(pwd, xmlTemplateFileName))

first_order = root.getElementsByTagName('first_order_landmark');
second_order = root.getElementsByTagName('second_order_landmark');

priors = xmlsupport.readSecondOrderLandmarks(second_order);
